//
//  UIImage+OSDImageHelpers.h
//  Play
//
//  Created by Skylar Schipper on 9/21/13.
//  Copyright (c) 2013 OpenSky, LLC. All rights reserved.
//

@import UIKit;

@interface UIImage (OSDImageHelpers)

- (UIColor *)osd_averageColor;

+ (UIImage *)osd_animatedImageFromGIFData:(NSData *)gifData;

- (UIImage *)osd_bluredImageWithRadius:(CGFloat)blurRadius tintColor:(UIColor *)tintColor error:(NSError **)error;
- (UIImage *)osd_lightBluredImage;

@end
