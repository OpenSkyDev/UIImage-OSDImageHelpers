//
//  UIImage+OSDImageHelpers.m
//  Play
//
//  Created by Skylar Schipper on 9/21/13.
//  Copyright (c) 2013 OpenSky, LLC. All rights reserved.
//

@import ImageIO;
@import Accelerate;

#import "UIImage+OSDImageHelpers.h"
#import <float.h>

@implementation UIImage (OSDImageHelpers)

- (UIColor *)osd_averageColor {
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    unsigned char rgba[4];
    CGContextRef context = CGBitmapContextCreate(rgba, 1, 1, 8, 4, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    
    CGContextDrawImage(context, CGRectMake(0, 0, 1, 1), [self CGImage]);
    CGColorSpaceRelease(colorSpace);
    CGContextRelease(context);
    
    if(rgba[3] > 0) {
        CGFloat alpha = ((CGFloat)rgba[3]) / 255.0;
        CGFloat multiplier = alpha / 255.0;
        return [UIColor colorWithRed:((CGFloat)rgba[0]) * multiplier
                               green:((CGFloat)rgba[1]) * multiplier
                                blue:((CGFloat)rgba[2]) * multiplier
                               alpha:alpha];
    } else {
        return [UIColor colorWithRed:((CGFloat)rgba[0]) / 255.0
                               green:((CGFloat)rgba[1]) / 255.0
                                blue:((CGFloat)rgba[2]) / 255.0
                               alpha:((CGFloat)rgba[3]) / 255.0];
    }
}

+ (UIImage *)osd_animatedImageFromGIFData:(NSData *)gifData {
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFTypeRef)gifData, NULL);
    if (!source) {
        return nil;
    }
    
    int64_t count = CGImageSourceGetCount(source);
    NSTimeInterval totalTime = 0.0;
    NSMutableArray *images = [NSMutableArray arrayWithCapacity:count];
    
    for (NSUInteger i = 0; i < count; i++) { @autoreleasepool {
        CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(source, i, NULL);
        CGImageRef frame = CGImageSourceCreateImageAtIndex(source, i, NULL);
        
        UIImage *imageFrame = [UIImage imageWithCGImage:frame];
        [images addObject:imageFrame];
        
        CGImageRelease(frame);
        
        if (properties) {
            CFDictionaryRef gifProperties = CFDictionaryGetValue(properties, kCGImagePropertyGIFDictionary);
            CFRelease(properties);
            if (gifProperties) {
                NSNumber *frameTime = (NSNumber *)CFDictionaryGetValue(gifProperties, kCGImagePropertyGIFDelayTime);
                totalTime += [frameTime doubleValue];

            }
        }
    }}
    
    CFRelease(source);
    return [UIImage animatedImageWithImages:images duration:totalTime];
}

- (UIImage *)osd_bluredImageWithRadius:(CGFloat)blurRadius tintColor:(UIColor *)tintColor error:(NSError **)error {
    // Sanity Checks
    if (self.size.width < 1 || self.size.height < 1) {
        NSString *errorReason = [NSString stringWithFormat:@"Invalid image input size.  Both dimensions must be >= 1 (%@)",NSStringFromCGSize(self.size)];
        *error = [NSError errorWithDomain:@"com.openskydev.imagehelpers"
                                     code:578
                                 userInfo:@{
                                            NSLocalizedFailureReasonErrorKey: errorReason
                                            }];
        return nil;
    }
    if (![self CGImage]) {
        NSString *errorReason = @"Image must be backed by a CGImage";
        *error = [NSError errorWithDomain:@"com.openskydev.imagehelpers"
                                     code:579
                                 userInfo:@{
                                            NSLocalizedFailureReasonErrorKey: errorReason
                                            }];
        return nil;
    }
    
    // Good to go
    CGRect imageRect = { CGPointZero, self.size };
    UIImage *effectImage = self;
    
    BOOL hasBlur = blurRadius > FLT_EPSILON;
    if (hasBlur) {
        UIGraphicsBeginImageContextWithOptions(self.size, NO, [[UIScreen mainScreen] scale]);
        CGContextRef effectInContext = UIGraphicsGetCurrentContext();
        CGContextScaleCTM(effectInContext, 1.0, -1.0);
        CGContextTranslateCTM(effectInContext, 0, -self.size.height);
        CGContextDrawImage(effectInContext, imageRect, [self CGImage]);
        
        vImage_Buffer effectInBuffer;
        effectInBuffer.data     = CGBitmapContextGetData(effectInContext);
        effectInBuffer.width    = CGBitmapContextGetWidth(effectInContext);
        effectInBuffer.height   = CGBitmapContextGetHeight(effectInContext);
        effectInBuffer.rowBytes = CGBitmapContextGetBytesPerRow(effectInContext);
        
        UIGraphicsBeginImageContextWithOptions(self.size, NO, [[UIScreen mainScreen] scale]);
        CGContextRef effectOutContext = UIGraphicsGetCurrentContext();
        vImage_Buffer effectOutBuffer;
        effectOutBuffer.data     = CGBitmapContextGetData(effectOutContext);
        effectOutBuffer.width    = CGBitmapContextGetWidth(effectOutContext);
        effectOutBuffer.height   = CGBitmapContextGetHeight(effectOutContext);
        effectOutBuffer.rowBytes = CGBitmapContextGetBytesPerRow(effectOutContext);
        
        if (hasBlur) {
            CGFloat inputRadius = blurRadius * [[UIScreen mainScreen] scale];
            uint32_t radius = floor(inputRadius * 3. * sqrt(2 * M_PI) / 4 + 0.5);
            if (radius % 2 != 1) {
                radius += 1;
            }
            vImageBoxConvolve_ARGB8888(&effectInBuffer, &effectOutBuffer, NULL, 0, 0, radius, radius, 0, kvImageEdgeExtend);
            vImageBoxConvolve_ARGB8888(&effectOutBuffer, &effectInBuffer, NULL, 0, 0, radius, radius, 0, kvImageEdgeExtend);
            vImageBoxConvolve_ARGB8888(&effectInBuffer, &effectOutBuffer, NULL, 0, 0, radius, radius, 0, kvImageEdgeExtend);
        }
        
        effectImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    
    UIGraphicsBeginImageContextWithOptions(self.size, NO, [[UIScreen mainScreen] scale]);
    CGContextRef outputContext = UIGraphicsGetCurrentContext();
    CGContextScaleCTM(outputContext, 1.0, -1.0);
    CGContextTranslateCTM(outputContext, 0, -self.size.height);
    
    CGContextDrawImage(outputContext, imageRect, [self CGImage]);
    
    if (hasBlur) {
        CGContextSaveGState(outputContext);
        CGContextDrawImage(outputContext, imageRect, [effectImage CGImage]);
        CGContextRestoreGState(outputContext);
    }
    
    if (tintColor) {
        CGContextSaveGState(outputContext);
        CGContextSetFillColorWithColor(outputContext, [tintColor CGColor]);
        CGContextFillRect(outputContext, imageRect);
        CGContextRestoreGState(outputContext);
    }
    
    UIImage *outputImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return outputImage;
}
- (UIImage *)osd_lightBluredImage {
    UIColor *tintColor = [UIColor colorWithWhite:1.0 alpha:0.3];
    return [self osd_bluredImageWithRadius:30 tintColor:tintColor error:nil];
}

@end
