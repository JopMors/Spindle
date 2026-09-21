// MediaRemote adapter.
//
// macOS 15.4+ blocks MRMediaRemoteGetNowPlayingInfo for ordinary apps: the
// callback fires with an empty dictionary. Apple *platform binaries* are still
// allowed. /usr/bin/perl is a platform binary, so loading this dylib from perl
// lets us read now-playing state and stream it to our app over stdout as JSON.
//
// Verified working on macOS 26.5.2. Approach inspired by ungive/mediaremote-adapter.
//
// Emits one JSON object per line on stdout. Artwork is base64 and only included
// when the artwork identifier changes, to keep the stream small.

#import <Foundation/Foundation.h>
#include <dlfcn.h>

static const char *kMediaRemotePath =
    "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote";

// Delay before the first query. Querying inside the dlopen constructor itself
// races the XPC machinery and the callback never fires.
static const NSTimeInterval kStartupDelay = 0.4;
// Coalesce bursts of notifications into a single emit.
static const NSTimeInterval kCoalesceDelay = 0.15;

typedef void (*MRGetNowPlayingInfoFn)(dispatch_queue_t, void (^)(NSDictionary *));
typedef void (*MRGetIsPlayingFn)(dispatch_queue_t, void (^)(Boolean));
typedef void (*MRGetDisplayIDFn)(dispatch_queue_t, void (^)(CFStringRef));
typedef void (*MRRegisterFn)(dispatch_queue_t);

static MRGetNowPlayingInfoFn gGetInfo;
static MRGetIsPlayingFn gGetIsPlaying;
static MRGetDisplayIDFn gGetDisplayID;
// Which app is playing. Blocked for ordinary processes exactly like the
// now-playing dictionary, so it has to be read from in here.
static NSString *gSourceBundleID = nil;
static NSString *gLastArtworkID = nil;
static NSString *gLastPayload = nil;
static dispatch_queue_t gWorkQueue;
static BOOL gEmitScheduled = NO;

#pragma mark - Output

static void emitLine(NSString *json) {
    // Suppress duplicates; MediaRemote is chatty about unchanged state.
    if (gLastPayload && [gLastPayload isEqualToString:json]) { return; }
    gLastPayload = [json copy];
    const char *bytes = json.UTF8String;
    if (!bytes) { return; }
    fwrite(bytes, 1, strlen(bytes), stdout);
    fputc('\n', stdout);
    fflush(stdout);
}

static void emitDictionary(NSDictionary *payload) {
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&error];
    if (!data) {
        fprintf(stderr, "adapter: json encode failed: %s\n", error.localizedDescription.UTF8String);
        return;
    }
    emitLine([[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
}

static void emitError(NSString *message) {
    emitDictionary(@{ @"type": @"error", @"message": message ?: @"unknown" });
}

#pragma mark - Payload building

static id stringOrNull(id value) {
    return [value isKindOfClass:NSString.class] ? value : NSNull.null;
}

static id numberOrNull(id value) {
    return [value isKindOfClass:NSNumber.class] ? value : NSNull.null;
}

static NSDictionary *buildPayload(NSDictionary *info, BOOL isPlaying) {
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[@"type"] = @"now-playing";
    payload[@"title"] = stringOrNull(info[@"kMRMediaRemoteNowPlayingInfoTitle"]);
    payload[@"artist"] = stringOrNull(info[@"kMRMediaRemoteNowPlayingInfoArtist"]);
    payload[@"album"] = stringOrNull(info[@"kMRMediaRemoteNowPlayingInfoAlbum"]);
    payload[@"duration"] = numberOrNull(info[@"kMRMediaRemoteNowPlayingInfoDuration"]);
    payload[@"elapsed"] = numberOrNull(info[@"kMRMediaRemoteNowPlayingInfoElapsedTime"]);
    payload[@"isPlaying"] = @(isPlaying);

    // Elapsed time is a reading taken *at* this timestamp, not "now". Without
    // it the progress bar starts every track a few hundred ms behind and drifts
    // further every time the app is idle between notifications.
    id timestamp = info[@"kMRMediaRemoteNowPlayingInfoTimestamp"];
    payload[@"timestamp"] = [timestamp isKindOfClass:NSDate.class]
        ? @([(NSDate *)timestamp timeIntervalSince1970])
        : NSNull.null;
    payload[@"playbackRate"] = numberOrNull(info[@"kMRMediaRemoteNowPlayingInfoPlaybackRate"]);

    // "3 of 82", the way the original's Now Playing screen counted.
    payload[@"queueIndex"] = numberOrNull(info[@"kMRMediaRemoteNowPlayingInfoQueueIndex"]);
    payload[@"queueCount"] = numberOrNull(info[@"kMRMediaRemoteNowPlayingInfoTotalQueueCount"]);

    // An empty dictionary means either nothing is playing, or we are being
    // sandboxed by the OS. The app treats "no title and no artist" as idle.
    payload[@"hasContent"] = @(info.count > 0);
    payload[@"sourceBundleID"] = gSourceBundleID ?: NSNull.null;

    id artworkID = info[@"kMRMediaRemoteNowPlayingInfoArtworkIdentifier"];
    NSString *artworkKey = nil;
    if ([artworkID isKindOfClass:NSString.class]) {
        artworkKey = artworkID;
    } else if ([artworkID isKindOfClass:NSNumber.class]) {
        artworkKey = [artworkID stringValue];
    }

    NSData *artwork = info[@"kMRMediaRemoteNowPlayingInfoArtworkData"];
    BOOL hasArtwork = [artwork isKindOfClass:NSData.class] && artwork.length > 0;

    if (!hasArtwork) {
        gLastArtworkID = nil;
        payload[@"artworkChanged"] = @YES;
        payload[@"artwork"] = NSNull.null;
        return payload;
    }

    // Fall back to hashing the bytes when no identifier is supplied.
    if (!artworkKey) {
        artworkKey = [NSString stringWithFormat:@"len:%lu", (unsigned long)artwork.length];
    }

    BOOL changed = !gLastArtworkID || ![gLastArtworkID isEqualToString:artworkKey];
    payload[@"artworkChanged"] = @(changed);
    payload[@"artwork"] = changed ? [artwork base64EncodedStringWithOptions:0] : NSNull.null;
    if (changed) { gLastArtworkID = [artworkKey copy]; }
    return payload;
}

#pragma mark - Querying

/// Emits using whatever source app is currently known.
static void emitWithKnownSource(void) {
    void (^withPlaying)(Boolean) = ^(Boolean isPlaying) {
        gGetInfo(gWorkQueue, ^(NSDictionary *info) {
            @autoreleasepool {
                emitDictionary(buildPayload(info ?: @{}, isPlaying));
            }
        });
    };

    if (gGetIsPlaying) {
        gGetIsPlaying(gWorkQueue, ^(Boolean playing) { withPlaying(playing); });
    } else {
        // Fall back to the playback rate inside the info dictionary.
        gGetInfo(gWorkQueue, ^(NSDictionary *info) {
            @autoreleasepool {
                NSNumber *rate = info[@"kMRMediaRemoteNowPlayingInfoPlaybackRate"];
                emitDictionary(buildPayload(info ?: @{}, rate.doubleValue > 0.0));
            }
        });
    }
}

static void performEmit(void) {
    if (!gGetInfo) { return; }
    if (!gGetDisplayID) {
        emitWithKnownSource();
        return;
    }
    // Resolved first so the frame carries the app that owns the audio, rather
    // than the one that owned it last time.
    gGetDisplayID(gWorkQueue, ^(CFStringRef identifier) {
        if (identifier) {
            gSourceBundleID = [(__bridge NSString *)identifier copy];
        }
        emitWithKnownSource();
    });
}

static void scheduleEmit(void) {
    if (gEmitScheduled) { return; }
    gEmitScheduled = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kCoalesceDelay * NSEC_PER_SEC)),
                   gWorkQueue, ^{
        gEmitScheduled = NO;
        performEmit();
    });
}

#pragma mark - Setup

static void observeNotifications(void) {
    NSArray<NSString *> *names = @[
        @"kMRMediaRemoteNowPlayingInfoDidChangeNotification",
        @"kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification",
        @"kMRMediaRemoteNowPlayingApplicationDidChangeNotification",
        @"kMRMediaRemoteNowPlayingPlaybackQueueDidChangeNotification",
    ];
    for (NSString *name in names) {
        [NSNotificationCenter.defaultCenter addObserverForName:name
                                                        object:nil
                                                         queue:nil
                                                    usingBlock:^(NSNotification *note) {
            scheduleEmit();
        }];
    }
}

static void setup(void) {
    void *handle = dlopen(kMediaRemotePath, RTLD_NOW);
    if (!handle) {
        emitError(@"Could not load MediaRemote framework");
        return;
    }

    gGetInfo = (MRGetNowPlayingInfoFn)dlsym(handle, "MRMediaRemoteGetNowPlayingInfo");
    gGetIsPlaying = (MRGetIsPlayingFn)dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying");
    gGetDisplayID =
        (MRGetDisplayIDFn)dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationDisplayID");
    MRRegisterFn registerFn =
        (MRRegisterFn)dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications");

    if (!gGetInfo) {
        emitError(@"MRMediaRemoteGetNowPlayingInfo unavailable on this macOS version");
        return;
    }

    if (registerFn) {
        registerFn(gWorkQueue);
        observeNotifications();
    } else {
        emitError(@"Live notifications unavailable; falling back to poll");
    }

    performEmit();
}

__attribute__((constructor))
static void adapterMain(void) {
    gWorkQueue = dispatch_queue_create("nl.jopmors.spindle.adapter", DISPATCH_QUEUE_SERIAL);
    // Deferred: running this inside the constructor races MediaRemote's XPC
    // setup and the first callback silently never fires.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kStartupDelay * NSEC_PER_SEC)),
                   gWorkQueue, ^{ setup(); });
}
