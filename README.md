# GVUserDefaults - 通过属性方法访问NSUserDefaults


平常使用NSUserDefaults，需要使用objectForKey:和setObjectForKey:来对NSUserDefaults中的值进行存取操作。使用GVUserDefaults，你可以通过属性的点方法来往NSUserDefaults中存取值，你只需给GVUserDefaults创建一个类别category，在这个类别里声明你想通过NSUserDefaults存取的属性，并声明这些属性是@dynamic即可。GVUserDefaults会在初始化方法中扫描所有的属性，为它们生成get方法和set方法，并在get方法和set方法中封装对NSUserDefaults的存取操作，这样你就可以通过属性访问NSUserDefaults。

例如：
给`GVUserDefaults`类创建一个category，在category的.h文件里声明一些属性，在.m文件里把这些属性声明为@dynamic:


    // .h
    @interface GVUserDefaults (Properties)
    @property (nonatomic, weak) NSString *userName;
    @property (nonatomic, weak) NSNumber *userId;
    @property (nonatomic) NSInteger integerValue;
    @property (nonatomic) BOOL boolValue;
    @property (nonatomic) float floatValue;
    @end

    // .m
    @implementation GVUserDefaults (Properties)
    @dynamic userName;
    @dynamic userId;
    @dynamic integerValue;
    @dynamic boolValue;
    @dynamic floatValue;
    @end

现在，不需要使用`[[NSUserDefaults standardUserDefaults] objectForKey:@"userName"]`, 你可以简单地通过 `[GVUserDefaults standardUserDefaults].userName`.

和
`[GVUserDefaults standardUserDefaults].userName = @"myusername";`
来往NSUserDefaults中存取值。

详细的使用方法见[源仓库](https://github.com/gangverk/GVUserDefaults)

`GVUserDefaults`代码只有不到300行，适合刚学习Objective-C runtime的朋友阅读。建议阅读之前先阅读苹果介绍runtime的官方文档[Objective-C Runtime Programming Guide](https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Introduction/Introduction.html)，尤其是关于Type Encodings和Declared Properties两节。


