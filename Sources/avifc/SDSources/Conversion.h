//
//  Conversion.h
//  SDWebImageAVIFCoder
//
//  Created by Ryo Hirafuji on 2020/03/15.
//

#pragma once
#if __has_include(<libavif/avif.h>)
#import <libavif/avif.h>
#else
#import "avif/avif.h"
#endif
#import <Accelerate/Accelerate.h>

#ifdef __cplusplus
extern "C" {
#endif
extern CGImageRef _Nullable SDCreateCGImageFromAVIF(avifImage * _Nonnull avif) __attribute__((visibility("hidden")));
#ifdef __cplusplus
}
#endif
extern CGImageRef _Nullable CreateImageFromBuffer(avifImage * _Nonnull avif, vImage_Buffer* _Nonnull result);
