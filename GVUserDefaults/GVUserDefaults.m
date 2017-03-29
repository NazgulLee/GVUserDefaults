//
//  GVUserDefaults.m
//  GVUserDefaults
//
//  Created by Kevin Renskers on 18-12-12.
//  Copyright (c) 2012 Gangverk. All rights reserved.
//

#import "GVUserDefaults.h"
#import <objc/runtime.h>

@interface GVUserDefaults ()
@property (strong, nonatomic) NSMutableDictionary *mapping;//键为属性的getter或setter方法名，值为在该getter或setter方法中往NSUserDefaults中存取值使用的key
@property (strong, nonatomic) NSUserDefaults *userDefaults;
@end

@implementation GVUserDefaults

enum TypeEncodings {
    Char                = 'c',
    Bool                = 'B',
    Short               = 's',
    Int                 = 'i',
    Long                = 'l',
    LongLong            = 'q',
    UnsignedChar        = 'C',
    UnsignedShort       = 'S',
    UnsignedInt         = 'I',
    UnsignedLong        = 'L',
    UnsignedLongLong    = 'Q',
    Float               = 'f',
    Double              = 'd',
    Object              = '@'
};
#pragma mark Accessor Methods
//userDefaults属性的get方法
- (NSUserDefaults *)userDefaults {
    if (!_userDefaults) {
        NSString *suiteName = nil;
        
        if ([NSUserDefaults instancesRespondToSelector:@selector(initWithSuiteName:)]) {//必为YES，这是担心initWithSuiteName方法被废弃？
            suiteName = [self _suiteName];//从用户定义的category中获取suiteName值
        }
        // 若用户在category中定义了suiteName，且不为空字符串，则使用initWithSuiteName方法初始化
        if (suiteName && suiteName.length) {
            _userDefaults = [[NSUserDefaults alloc] initWithSuiteName:suiteName];
        } else {// 否则，使用standardUserDefaults
            _userDefaults = [NSUserDefaults standardUserDefaults];
        }
    }

    return _userDefaults;
}
#pragma mark 往NSUserDefaults中存取值使用的key
//默认使用的key是属性名字，若用户在category中定义了transformKey方法，则调用之
- (NSString *)defaultsKeyForPropertyNamed:(char const *)propertyName {
    NSString *key = [NSString stringWithFormat:@"%s", propertyName];
    return [self _transformKey:key];
}
//在该selector对应的getter方法或setter方法中往NSUserDefaults存取值时使用的key
- (NSString *)defaultsKeyForSelector:(SEL)selector {
    return [self.mapping objectForKey:NSStringFromSelector(selector)];
}
#pragma mark 生成的get方法和set方法的模版，self和_cmd是OC方法的两个隐藏参数
static long long longLongGetter(GVUserDefaults *self, SEL _cmd) {
    NSString *key = [self defaultsKeyForSelector:_cmd];
    return [[self.userDefaults objectForKey:key] longLongValue];
}

static void longLongSetter(GVUserDefaults *self, SEL _cmd, long long value) {
    NSString *key = [self defaultsKeyForSelector:_cmd];
    NSNumber *object = [NSNumber numberWithLongLong:value];
    [self.userDefaults setObject:object forKey:key];
}

static bool boolGetter(GVUserDefaults *self, SEL _cmd) {
    NSString *key = [self defaultsKeyForSelector:_cmd];
    return [self.userDefaults boolForKey:key];
}

static void boolSetter(GVUserDefaults *self, SEL _cmd, bool value) {
    NSString *key = [self defaultsKeyForSelector:_cmd];
    [self.userDefaults setBool:value forKey:key];
}

static int integerGetter(GVUserDefaults *self, SEL _cmd) {
    NSString *key = [self defaultsKeyForSelector:_cmd];
    return (int)[self.userDefaults integerForKey:key];
}

static void integerSetter(GVUserDefaults *self, SEL _cmd, int value) {
    NSString *key = [self defaultsKeyForSelector:_cmd];
    [self.userDefaults setInteger:value forKey:key];
}

static float floatGetter(GVUserDefaults *self, SEL _cmd) {
    NSString *key = [self defaultsKeyForSelector:_cmd];
    return [self.userDefaults floatForKey:key];
}

static void floatSetter(GVUserDefaults *self, SEL _cmd, float value) {
    NSString *key = [self defaultsKeyForSelector:_cmd];
    [self.userDefaults setFloat:value forKey:key];
}

static double doubleGetter(GVUserDefaults *self, SEL _cmd) {
    NSString *key = [self defaultsKeyForSelector:_cmd];
    return [self.userDefaults doubleForKey:key];
}

static void doubleSetter(GVUserDefaults *self, SEL _cmd, double value) {
    NSString *key = [self defaultsKeyForSelector:_cmd];
    [self.userDefaults setDouble:value forKey:key];
}

static id objectGetter(GVUserDefaults *self, SEL _cmd) {
    NSString *key = [self defaultsKeyForSelector:_cmd];
    return [self.userDefaults objectForKey:key];
}

static void objectSetter(GVUserDefaults *self, SEL _cmd, id object) {
    NSString *key = [self defaultsKeyForSelector:_cmd];
    if (object) {
        [self.userDefaults setObject:object forKey:key];
    } else {
        [self.userDefaults removeObjectForKey:key];
    }
}

#pragma mark - Begin

+ (instancetype)standardUserDefaults {
    static dispatch_once_t pred;
    static GVUserDefaults *sharedInstance = nil;
    dispatch_once(&pred, ^{ sharedInstance = [[self alloc] init]; });
    return sharedInstance;
}
// 在diagnostic push和对应的diagnostic pop之间忽略编译器警告"-Wundeclared-selector"和"-Warc-performSelector-leaks"
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wundeclared-selector"
#pragma GCC diagnostic ignored "-Warc-performSelector-leaks"

- (instancetype)init {
    self = [super init];
    if (self) {
        SEL setupDefaultSEL = NSSelectorFromString([NSString stringWithFormat:@"%@pDefaults", @"setu"]);
        if ([self respondsToSelector:setupDefaultSEL]) {//若用户在category中定义了setupDefaults方法，则向self.userDefaults注册用户在setupDefaults方法中返回的defaults
            NSDictionary *defaults = [self performSelector:setupDefaultSEL];
            NSMutableDictionary *mutableDefaults = [NSMutableDictionary dictionaryWithCapacity:[defaults count]];
            for (NSString *key in defaults) {
                id value = [defaults objectForKey:key];
                NSString *transformedKey = [self _transformKey:key];//使用用户定义的transformKey方法对key做转换
                [mutableDefaults setObject:value forKey:transformedKey];
            }
            [self.userDefaults registerDefaults:mutableDefaults];
        }

        [self generateAccessorMethods];//为用户在category中声明的属性生成accessor methods
    }

    return self;
}

- (NSString *)_transformKey:(NSString *)key {
    if ([self respondsToSelector:@selector(transformKey:)]) {
        return [self performSelector:@selector(transformKey:) withObject:key];
    }

    return key;
}
// 返回用户在category中可能定义的suitName或者suiteName
- (NSString *)_suiteName {
    // Backwards compatibility (v 1.0.0)
    if ([self respondsToSelector:@selector(suitName)]) {
        return [self performSelector:@selector(suitName)];
    }

    if ([self respondsToSelector:@selector(suiteName)]) {
        return [self performSelector:@selector(suiteName)];
    }

    return nil;
}

#pragma GCC diagnostic pop
//为用户在category中声明的属性生成accessor methods
- (void)generateAccessorMethods {
    unsigned int count = 0;
    objc_property_t *properties = class_copyPropertyList([self class], &count);//扫描所有属性

    self.mapping = [NSMutableDictionary dictionary];

    for (int i = 0; i < count; ++i) {
        objc_property_t property = properties[i];
        const char *name = property_getName(property);//获取属性名字
        const char *attributes = property_getAttributes(property);//获取属性的修饰符生成的attributes字符串

        char *getter = strstr(attributes, ",G");
        if (getter) {//attributes中含有",G"，说明用户指定了getter方法名字
            getter = strdup(getter + 2);
            getter = strsep(&getter, ",");
        } else {//用户没有指定getter方法名，则使用属性名字作为getter方法名
            getter = strdup(name);
        }
        SEL getterSel = sel_registerName(getter);//向运行时注册这个getter方法
        free(getter);

        char *setter = strstr(attributes, ",S");
        if (setter) {//attributes中含有",S"，说明用户指定了setter方法名字
            setter = strdup(setter + 2);
            setter = strsep(&setter, ",");
        } else {//用户没有指定setter方法名，则使用set＋首字母大写的属性名作为setter方法名
            asprintf(&setter, "set%c%s:", toupper(name[0]), name + 1);
        }
        SEL setterSel = sel_registerName(setter);//向运行时注册这个setter方法
        free(setter);

        NSString *key = [self defaultsKeyForPropertyNamed:name];//在getter和setter方法中向NSUserDefaults存取此属性时使用的key
        [self.mapping setValue:key forKey:NSStringFromSelector(getterSel)];
        [self.mapping setValue:key forKey:NSStringFromSelector(setterSel)];

        IMP getterImp = NULL;
        IMP setterImp = NULL;
        char type = attributes[1];//获取属性类型
        switch (type) {
            case Short:
            case Long:
            case LongLong:
            case UnsignedChar:
            case UnsignedShort:
            case UnsignedInt:
            case UnsignedLong:
            case UnsignedLongLong:
                getterImp = (IMP)longLongGetter;
                setterImp = (IMP)longLongSetter;
                break;

            case Bool:
            case Char:
                getterImp = (IMP)boolGetter;
                setterImp = (IMP)boolSetter;
                break;

            case Int:
                getterImp = (IMP)integerGetter;
                setterImp = (IMP)integerSetter;
                break;

            case Float:
                getterImp = (IMP)floatGetter;
                setterImp = (IMP)floatSetter;
                break;

            case Double:
                getterImp = (IMP)doubleGetter;
                setterImp = (IMP)doubleSetter;
                break;

            case Object:
                getterImp = (IMP)objectGetter;
                setterImp = (IMP)objectSetter;
                break;

            default:
                free(properties);
                [NSException raise:NSInternalInconsistencyException format:@"Unsupported type of property \"%s\" in class %@", name, self];
                break;
        }

        char types[5];//描述了往getter或setter方法返回类型传递的参数类型

        snprintf(types, 4, "%c@:", type);//getter方法，返回类型为type即属性本身的类型，参数为一个对象(@标识)和一个selector(:标识)，即self和_cmd
        class_addMethod([self class], getterSel, getterImp, types);//向本类添加此属性的getter方法
        
        snprintf(types, 5, "v@:%c", type);//setter方法，返回类型为void(v标识），参数为一个对象(@标识)即self,一个selector(:标识)即_cmd，以及type即属性本身的类型
        class_addMethod([self class], setterSel, setterImp, types);//向本类添加此属性的setter方法
    }

    free(properties);
}

@end
