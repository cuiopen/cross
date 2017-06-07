

#include "CAFontProcesstor.h"
#include "images/CAImage.h"

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

NSTextAlignment _calculateTextAlignment(CrossApp::CATextAlignment alignment)
{
    NSTextAlignment nsAlignment;
    switch (alignment)
    {
        case CrossApp::CATextAlignment::Right:
            nsAlignment = NSTextAlignmentRight;
        case CrossApp::CATextAlignment::Center:
            nsAlignment = NSTextAlignmentCenter;
            break;
        case CrossApp::CATextAlignment::Left:
        default:
            nsAlignment = NSTextAlignmentLeft;
            break;
    }
    
    return nsAlignment;
}

NSRect _calculateStringSize(NSAttributedString *str, id font, CGSize constrainSize, bool enableWrap, int overflow)
{
    NSSize textRect = NSZeroSize;
    textRect.width = constrainSize.width > 0 ? constrainSize.width
    : CGFLOAT_MAX;
    textRect.height = constrainSize.height > 0 ? constrainSize.height
    : CGFLOAT_MAX;
    
    if (overflow == 1)
    {
        if (!enableWrap)
        {
            textRect.width = CGFLOAT_MAX;
            textRect.height = CGFLOAT_MAX;
        }
        else
        {
            textRect.height = CGFLOAT_MAX;
        }
    }
    
    NSRect dim = NSZeroRect;
#ifdef __MAC_10_11
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= __MAC_10_11
    dim.size = [str boundingRectWithSize:textRect options:(NSStringDrawingOptions)(NSStringDrawingUsesLineFragmentOrigin) context:nil].size;
#else
    dim.size = [str boundingRectWithSize:textRect options:(NSStringDrawingOptions)(NSStringDrawingUsesLineFragmentOrigin)].size;
#endif
#else
    dim.size = [str boundingRectWithSize:textRect options:(NSStringDrawingOptions)(NSStringDrawingUsesLineFragmentOrigin)].size;
#endif
    
    
    dim.size.width = ceilf(dim.size.width);
    dim.size.height = ceilf(dim.size.height);
    
    return dim;
}

static NSFont* _createSystemFont(const std::string& fontName, unsigned int size)
{
    NSString * fntName = [NSString stringWithUTF8String:fontName.c_str()];
    fntName = [[fntName lastPathComponent] stringByDeletingPathExtension];
    
    CGFloat fontSize = size;
    
    // font
    NSFont *font = [[NSFontManager sharedFontManager]
                    fontWithFamily:fntName
                    traits:NSUnboldFontMask | NSUnitalicFontMask
                    weight:0
                    size:fontSize];
    
    if (font == nil) {
        font = [[NSFontManager sharedFontManager]
                fontWithFamily:@"Arial"
                traits:NSUnboldFontMask | NSUnitalicFontMask
                weight:0
                size:fontSize];
    }
    return font;
}

NS_CC_BEGIN

CAImage* CAFontProcesstor::imageForText(const std::string& text, const CAFont& font, DSize& dim)
{
    CAImage* ret = nullptr;
    do {
        CC_BREAK_IF(text.empty());
        NSString * str  = [NSString stringWithUTF8String:text.c_str()];
        CC_BREAK_IF(!str);
        
        int shrinkFontSize = (font.fontSize);
        id nsfont = _createSystemFont(font.fontName, shrinkFontSize);
        CC_BREAK_IF(!nsfont);
        
        dim.width = (dim.width);
        dim.height = (dim.height);
        
        // color
        NSColor* foregroundColor = [NSColor colorWithDeviceRed:font.color.r/255.0
                                                         green:font.color.g/255.0
                                                          blue:font.color.b/255.0
                                                         alpha:font.color.a/255.0];
        
        // alignment
        NSTextAlignment textAlign = _calculateTextAlignment(font.textAlignment);
        
        NSMutableParagraphStyle *paragraphStyle = [[[NSMutableParagraphStyle alloc] init] autorelease];
        paragraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
        [paragraphStyle setAlignment:textAlign];
        
        // attribute
        NSMutableDictionary* tokenAttributesDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                                    foregroundColor,   NSForegroundColorAttributeName,
                                                    nsfont,            NSFontAttributeName,
                                                    paragraphStyle,    NSParagraphStyleAttributeName,
                                                    nil];
        
        if (font.color == CAColor4B::CLEAR && font.stroke.strokeEnabled)
        {
            foregroundColor = [NSColor colorWithDeviceRed:font.stroke.strokeColor.r / 255.f
                                                    green:font.stroke.strokeColor.g / 255.f
                                                     blue:font.stroke.strokeColor.b / 255.f
                                                    alpha:font.stroke.strokeColor.a / 255.f];
            
            
            [tokenAttributesDict setObject:@(font.stroke.strokeSize) forKey:NSStrokeWidthAttributeName];
            [tokenAttributesDict setObject:foregroundColor forKey:NSStrokeColorAttributeName];
        }
        
        if (font.italics) [tokenAttributesDict setObject:@(font.italicsValue) forKey:NSObliquenessAttributeName];
        if (font.underLine) [tokenAttributesDict setObject:@(NSUnderlineStyleSingle) forKey:NSUnderlineStyleAttributeName];
        if (font.deleteLine) [tokenAttributesDict setObject:@(NSUnderlineStyleSingle) forKey:NSStrikethroughStyleAttributeName];
        
        if (font.shadow.shadowEnabled)
        {
            NSShadow* shadow = [[[NSShadow alloc] init] autorelease];
            
            [shadow setShadowOffset:CGSizeMake(font.shadow.shadowOffset.width, font.shadow.shadowOffset.height)];
            [shadow setShadowBlurRadius:font.shadow.shadowBlur];
            
            NSColor* shadowColor = [NSColor colorWithDeviceRed:font.shadow.shadowColor.r / 255.f
                                                         green:font.shadow.shadowColor.g / 255.f
                                                          blue:font.shadow.shadowColor.b / 255.f
                                                         alpha:font.shadow.shadowColor.a / 255.f];
            
            [shadow setShadowColor:shadowColor];
            
            [tokenAttributesDict setObject:shadow forKey:NSShadowAttributeName];
        }
        
        NSAttributedString *stringWithAttributes = [[[NSAttributedString alloc] initWithString:str attributes:tokenAttributesDict] autorelease];
        
        NSRect textRect = _calculateStringSize(stringWithAttributes, nsfont, CGSizeMake(dim.width, dim.height), font.wordWrap, 0);
        
        // Mac crashes if the width or height is 0
        CC_BREAK_IF(textRect.size.width <= 0 || textRect.size.height <= 0);
        
        if (font.italics)
        {
            float increase = shrinkFontSize * font.italicsValue * 0.5f;
            if (font.italicsValue > 0)
            {
                textRect.size.width += increase;
            }
            else if (font.italicsValue < 0)
            {
                textRect.size.width -= increase;
                textRect.origin.x -= increase;
            }
        }

        NSInteger POTWide = textRect.size.width;
        NSInteger POTHigh = textRect.size.height;
        
        [[NSGraphicsContext currentContext] setShouldAntialias:NO];
        
        NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(POTWide, POTHigh)];
        [image lockFocus];
        // patch for mac retina display and lableTTF
        [[NSAffineTransform transform] set];
        [stringWithAttributes drawInRect:textRect];
        
        if (font.bold)
        {
            
            NSMutableDictionary* tokenAttributesDict2 = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                                         foregroundColor,   NSForegroundColorAttributeName,
                                                         nsfont,            NSFontAttributeName,
                                                         paragraphStyle,    NSParagraphStyleAttributeName,
                                                         nil];
            
            if (font.italics) [tokenAttributesDict2 setObject:@(font.italicsValue) forKey:NSObliquenessAttributeName];
            if (font.underLine) [tokenAttributesDict2 setObject:@(NSUnderlineStyleSingle) forKey:NSUnderlineStyleAttributeName];
            if (font.deleteLine) [tokenAttributesDict2 setObject:@(NSUnderlineStyleSingle) forKey:NSStrikethroughStyleAttributeName];
            
            [tokenAttributesDict2 setObject:@(shrinkFontSize / 15.f) forKey:NSStrokeWidthAttributeName];
            [tokenAttributesDict2 setObject:foregroundColor forKey:NSStrokeColorAttributeName];
            
            NSAttributedString *strokeString = [[[NSAttributedString alloc] initWithString:str attributes:tokenAttributesDict2] autorelease];
            
            [strokeString drawInRect:textRect];
        }
        
        if (font.stroke.strokeEnabled)
        {
            NSColor *strokeColor = [NSColor colorWithDeviceRed:font.stroke.strokeColor.r / 255.f
                                                         green:font.stroke.strokeColor.g / 255.f
                                                          blue:font.stroke.strokeColor.b / 255.f
                                                         alpha:font.stroke.strokeColor.a / 255.f];
            
            
            NSMutableDictionary* tokenAttributesDict2 = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                                         foregroundColor,   NSForegroundColorAttributeName,
                                                         nsfont,            NSFontAttributeName,
                                                         paragraphStyle,    NSParagraphStyleAttributeName, nil];
            
            if (font.italics) [tokenAttributesDict2 setObject:@(font.italicsValue) forKey:NSObliquenessAttributeName];
            if (font.underLine) [tokenAttributesDict2 setObject:@(NSUnderlineStyleSingle) forKey:NSUnderlineStyleAttributeName];
            if (font.deleteLine) [tokenAttributesDict2 setObject:@(NSUnderlineStyleSingle) forKey:NSStrikethroughStyleAttributeName];
            
            [tokenAttributesDict2 setObject:@(font.stroke.strokeSize) forKey:NSStrokeWidthAttributeName];
            [tokenAttributesDict2 setObject:strokeColor forKey:NSStrokeColorAttributeName];
            
            NSAttributedString *strokeString =[[[NSAttributedString alloc] initWithString:str attributes:tokenAttributesDict2] autorelease];
            
            [strokeString drawInRect:textRect];
            
        }
        
        
        NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect (0.0f, 0.0f, POTWide, POTHigh)];
        [image unlockFocus];
        
        unsigned int pixelsWide = static_cast<unsigned int>(POTWide);
        unsigned int pixelsHigh = static_cast<unsigned int>(POTHigh);
        
        dim = DSize((pixelsWide), (pixelsHigh));
        
        ssize_t length = pixelsWide * pixelsHigh * 4;
        unsigned char *bytes = (unsigned char*)malloc(sizeof(unsigned char) * length);
        memcpy(bytes, (unsigned char*) [bitmap bitmapData], length);
        
        [bitmap release];
        [image release];
        
        CAData* data = new CAData();
        data->fastSet(bytes, length);
        ret = CAImage::createWithRawDataNoCache(data, CAImage::PixelFormat::RGBA8888, pixelsWide, pixelsHigh);
        data->release();
    } while (0);
    
    
    return ret;
}

float CAFontProcesstor::heightForFont(const CAFont& font)
{
    float ret = 0;
    do
    {
        int shrinkFontSize = (font.fontSize);
        id nsfont = _createSystemFont(font.fontName, shrinkFontSize);
        CC_BREAK_IF(!nsfont);
        
        // alignment
        NSTextAlignment textAlign = _calculateTextAlignment(font.textAlignment);
        
        NSMutableParagraphStyle *paragraphStyle = [[[NSMutableParagraphStyle alloc] init] autorelease];
        paragraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
        [paragraphStyle setAlignment:textAlign];
        
        NSMutableDictionary* tokenAttributesDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                                    [NSColor whiteColor],   NSForegroundColorAttributeName,
                                                    nsfont,                NSFontAttributeName,
                                                    paragraphStyle,         NSParagraphStyleAttributeName,
                                                    nil];
        
        
        if (font.color == CAColor4B::CLEAR && font.stroke.strokeEnabled)
        {
            [tokenAttributesDict setObject:@(font.stroke.strokeSize) forKey:NSStrokeWidthAttributeName];
            [tokenAttributesDict setObject:[NSColor whiteColor] forKey:NSStrokeColorAttributeName];
        }
        
        if (font.italics) [tokenAttributesDict setObject:@(font.italicsValue) forKey:NSObliquenessAttributeName];
        if (font.underLine) [tokenAttributesDict setObject:@(NSUnderlineStyleSingle) forKey:NSUnderlineStyleAttributeName];

        if (font.shadow.shadowEnabled)
        {
            NSShadow* shadow = [[[NSShadow alloc] init] autorelease];
            
            [shadow setShadowOffset:CGSizeMake(font.shadow.shadowOffset.width, font.shadow.shadowOffset.height)];
            [shadow setShadowBlurRadius:font.shadow.shadowBlur];
            
            NSColor* shadowColor = [NSColor whiteColor];
            
            [shadow setShadowColor:shadowColor];
            
            [tokenAttributesDict setObject:shadow forKey:NSShadowAttributeName];
        }
        NSAttributedString* str = [[[NSAttributedString alloc] initWithString:@"A" attributes:tokenAttributesDict] autorelease];
        NSSize textSize = NSMakeSize(CGFLOAT_MAX, 0);
        NSSize dim;
#ifdef __MAC_10_11
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= __MAC_10_11
        dim = [str boundingRectWithSize:textSize options:(NSStringDrawingOptions)(NSStringDrawingUsesLineFragmentOrigin) context:nil].size;
#else
        dim = [str boundingRectWithSize:textSize options:(NSStringDrawingOptions)(NSStringDrawingUsesLineFragmentOrigin)].size;
#endif
#else
        dim = [str boundingRectWithSize:textSize options:(NSStringDrawingOptions)(NSStringDrawingUsesLineFragmentOrigin)].size;
#endif
        
        ret = ceilf((dim.height));
        
    } while (0);
    
    
    return ret;
}

float CAFontProcesstor::heightForTextAtWidth(const std::string& text, const CAFont& font, float width)
{
    float ret = 0;
    do
    {
        CC_BREAK_IF(text.empty());
        
        NSString* string = [NSString stringWithUTF8String:text.c_str()];
        CC_BREAK_IF(!string);
        
        int shrinkFontSize = (font.fontSize);
        id nsfont = _createSystemFont(font.fontName, shrinkFontSize);
        CC_BREAK_IF(!nsfont);
        
        // alignment
        NSTextAlignment textAlign = _calculateTextAlignment(font.textAlignment);
        
        NSMutableParagraphStyle *paragraphStyle = [[[NSMutableParagraphStyle alloc] init] autorelease];
        paragraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
        [paragraphStyle setAlignment:textAlign];
        
        // attribute
        NSMutableDictionary* tokenAttributesDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                                    [NSColor whiteColor],   NSForegroundColorAttributeName,
                                                    nsfont,                NSFontAttributeName,
                                                    paragraphStyle,         NSParagraphStyleAttributeName,
                                                    nil];
        
        
        if (font.color == CAColor4B::CLEAR && font.stroke.strokeEnabled)
        {
            [tokenAttributesDict setObject:@(font.stroke.strokeSize) forKey:NSStrokeWidthAttributeName];
            [tokenAttributesDict setObject:[NSColor whiteColor] forKey:NSStrokeColorAttributeName];
        }
        
        if (font.italics) [tokenAttributesDict setObject:@(font.italicsValue) forKey:NSObliquenessAttributeName];
        if (font.underLine) [tokenAttributesDict setObject:@(NSUnderlineStyleSingle) forKey:NSUnderlineStyleAttributeName];
        
        if (font.shadow.shadowEnabled)
        {
            NSShadow* shadow = [[[NSShadow alloc] init] autorelease];
            
            [shadow setShadowOffset:CGSizeMake(font.shadow.shadowOffset.width, font.shadow.shadowOffset.height)];
            [shadow setShadowBlurRadius:font.shadow.shadowBlur];
            
            NSColor* shadowColor = [NSColor whiteColor];
            
            [shadow setShadowColor:shadowColor];
            
            [tokenAttributesDict setObject:shadow forKey:NSShadowAttributeName];
        }
        
        NSAttributedString* str = [[[NSAttributedString alloc] initWithString:string attributes:tokenAttributesDict] autorelease];
        NSSize textSize = NSMakeSize(width, 0);
        NSSize dim;
#ifdef __MAC_10_11
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= __MAC_10_11
        dim = [str boundingRectWithSize:textSize options:(NSStringDrawingOptions)(NSStringDrawingUsesLineFragmentOrigin) context:nil].size;
#else
        dim = [str boundingRectWithSize:textSize options:(NSStringDrawingOptions)(NSStringDrawingUsesLineFragmentOrigin)].size;
#endif
#else
        dim = [str boundingRectWithSize:textSize options:(NSStringDrawingOptions)(NSStringDrawingUsesLineFragmentOrigin)].size;
#endif
        
        ret = ceilf((dim.height));
        
    } while (0);
    
    return ret;
}

float CAFontProcesstor::widthForTextAtOneLine(const std::string& text, const CAFont& font)
{
    float ret = 0;
    do
    {
        CC_BREAK_IF(text.empty());
        NSString* string = [NSString stringWithUTF8String:text.c_str()];
        CC_BREAK_IF(!string);
        
        int shrinkFontSize = (font.fontSize);
        id nsfont = _createSystemFont(font.fontName, shrinkFontSize);
        CC_BREAK_IF(!nsfont);
        
        // alignment
        NSTextAlignment textAlign = _calculateTextAlignment(font.textAlignment);
        
        NSMutableParagraphStyle *paragraphStyle = [[[NSMutableParagraphStyle alloc] init] autorelease];
        paragraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
        [paragraphStyle setAlignment:textAlign];
        
        // attribute
        NSMutableDictionary* tokenAttributesDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                                    [NSColor whiteColor],   NSForegroundColorAttributeName,
                                                    nsfont,                NSFontAttributeName,
                                                    paragraphStyle,         NSParagraphStyleAttributeName,
                                                    nil];
        
        
        if (font.color == CAColor4B::CLEAR && font.stroke.strokeEnabled)
        {
            [tokenAttributesDict setObject:@(font.stroke.strokeSize) forKey:NSStrokeWidthAttributeName];
            [tokenAttributesDict setObject:[NSColor whiteColor] forKey:NSStrokeColorAttributeName];
        }
        
        if (font.italics) [tokenAttributesDict setObject:@(font.italicsValue) forKey:NSObliquenessAttributeName];
        
        if (font.shadow.shadowEnabled)
        {
            NSShadow* shadow = [[[NSShadow alloc] init] autorelease];
            
            [shadow setShadowOffset:CGSizeMake(font.shadow.shadowOffset.width, font.shadow.shadowOffset.height)];
            [shadow setShadowBlurRadius:font.shadow.shadowBlur];
            
            NSColor* shadowColor = [NSColor whiteColor];
            
            [shadow setShadowColor:shadowColor];
            
            [tokenAttributesDict setObject:shadow forKey:NSShadowAttributeName];
        }
        
        NSAttributedString* str = [[[NSAttributedString alloc] initWithString:string attributes:tokenAttributesDict] autorelease];
        NSSize textSize = NSMakeSize(CGFLOAT_MAX, 0);
        NSSize dim;
#ifdef __MAC_10_11
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= __MAC_10_11
        dim = [str boundingRectWithSize:textSize options:(NSStringDrawingOptions)(NSStringDrawingUsesLineFragmentOrigin) context:nil].size;
#else
        dim = [str boundingRectWithSize:textSize options:(NSStringDrawingOptions)(NSStringDrawingUsesLineFragmentOrigin)].size;
#endif
#else
        dim = [str boundingRectWithSize:textSize options:(NSStringDrawingOptions)(NSStringDrawingUsesLineFragmentOrigin)].size;
#endif
        
        if (font.italics)
        {
            float increase = shrinkFontSize * font.italicsValue * 0.5f;
            if (font.italicsValue > 0)
            {
                dim.width += increase;
            }
            else if (font.italicsValue < 0)
            {
                dim.width -= increase;
            }
        }
        
        ret = ceilf((dim.width));
        
    } while (0);
    return ret;
}

NS_CC_END