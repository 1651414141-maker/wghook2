typedef void *id;
typedef void *Class;
typedef void *Method;
typedef void *SEL;
typedef void (*IMP)(void);

extern Class *objc_copyClassList(unsigned int *outCount);
extern Method class_getInstanceMethod(Class cls, SEL name);
extern IMP method_setImplementation(Method m, IMP imp);
extern SEL sel_registerName(const char *str);

static void wg_nop(id self, SEL _cmd) { (void)self; (void)_cmd; }
static int wg_yes(id self, SEL _cmd) { (void)self; (void)_cmd; return 1; }

static int wg_patch(const char *name, IMP imp) {
    unsigned int n = 0, i;
    Class *list = objc_copyClassList(&n);
    if (!list) return 0;
    SEL sel = sel_registerName(name);
    for (i = 0; i < n; i++) {
        if (!list[i]) continue;
        Method m = class_getInstanceMethod(list[i], sel);
        if (m) method_setImplementation(m, imp);
    }
    return (int)n;
}

__attribute__((constructor))
static void wg_init(void) {
    wg_patch("forceCrashApp", (IMP)wg_nop);
    wg_patch("forascesd", (IMP)wg_yes);
}
