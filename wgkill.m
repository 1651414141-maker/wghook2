#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define WGLOG(fmt, ...) NSLog((@"[wg] " fmt), ##__VA_ARGS__)

static BOOL wg_ret_yes(id self, SEL _cmd) { return YES; }
static void wg_ret_void(id self, SEL _cmd) { }

static int wg_patch_all(SEL sel, IMP imp, const char *tag) {
    unsigned int n = 0;
    Class *classes = objc_copyClassList(&n);
    int hit = 0;
    for (unsigned i = 0; i < n; i++) {
        if (!classes[i]) continue;
        Method m = class_getInstanceMethod(classes[i], sel);
        if (m) { method_setImplementation(m, imp); hit++; }
    }
    free(classes);
    WGLOG(@"patch %s -> %d classes", tag, hit);
    return hit;
}

static void wg_pass(void) {
    wg_patch_all(NSSelectorFromString(@"forceCrashApp"), (IMP)wg_ret_void, "forceCrashApp");
    wg_patch_all(NSSelectorFromString(@"forascesd"), (IMP)wg_ret_yes, "forascesd");
}

static id (*o_URL)(id, SEL, NSString *);
static id wg_URL(id s, SEL c, NSString *u) {
    WGLOG(@"URL=%@", u);
    return o_URL ? o_URL(s, c, u) : nil;
}

static id (*o_jsonOut)(id, SEL, id, NSInteger, NSError **);
static id wg_jsonOut(id s, SEL c, id o, NSInteger opt, NSError **e) {
    WGLOG(@"JSON out=%@", o);
    return o_jsonOut ? o_jsonOut(s, c, o, opt, e) : nil;
}

static id (*o_jsonIn)(id, SEL, id, NSInteger, NSError **);
static id wg_jsonIn(id s, SEL c, id d, NSInteger opt, NSError **e) {
    NSString *t = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
    WGLOG(@"JSON in=%@", t ? t : @"<binary>");
    return o_jsonIn ? o_jsonIn(s, c, d, opt, e) : nil;
}

__attribute__((constructor))
static void wg_init(void) {
    wg_pass();

    Method m;
    m = class_getClassMethod([NSURL class], @selector(URLWithString:));
    if (m) { o_URL = (id (*)(id, SEL, NSString *))method_getImplementation(m);
             method_setImplementation(m, (IMP)wg_URL); }

    m = class_getClassMethod([NSJSONSerialization class], @selector(dataWithJSONObject:options:error:));
    if (m) { o_jsonOut = (id (*)(id, SEL, id, NSInteger, NSError **))method_getImplementation(m);
             method_setImplementation(m, (IMP)wg_jsonOut); }

    m = class_getClassMethod([NSJSONSerialization class], @selector(JSONObjectWithData:options:error:));
    if (m) { o_jsonIn = (id (*)(id, SEL, id, NSInteger, NSError **))method_getImplementation(m);
             method_setImplementation(m, (IMP)wg_jsonIn); }

    for (NSNumber *d in @[@1.0, @3.0, @8.0]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(d.doubleValue * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ wg_pass(); });
    }
    WGLOG(@"loaded");
}
