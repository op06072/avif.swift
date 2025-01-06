//
//  AVIFDataDecoder.m
//
//  Created by Radzivon Bartoshyk on 01/05/2022.
//

#import <Foundation/Foundation.h>
#import "libyuv.h"
#if __has_include(<libavif/avif.h>)
#import <libavif/avif.h>
#else
#import "avif/avif.h"
#endif
#import <Accelerate/Accelerate.h>
#import "AVIFDataDecoder.h"
#import "AVIFRGBAMultiplier.h"
#import <vector>
#import "AVIFImageXForm.h"
#import "HDRColorTransfer.h"
#import <thread>
#import <TargetConditionals.h>

#if !TARGET_OS_IPHONE && !TARGET_OS_IOS && !TARGET_OS_TV && !TARGET_OS_WATCH
    #define AVIF_PLUGIN_MAC 1
#else
    #define AVIF_PLUGIN_MAC 0
#endif

#if TARGET_OS_IOS || TARGET_OS_TV
    #define AVIF_PLUGIN_UIKIT 1
#else
    #define AVIF_PLUGIN_UIKIT 0
#endif

#if TARGET_OS_IOS
    #define AVIF_PLUGIN_IOS 1
#else
    #define AVIF_PLUGIN_IOS 0
#endif

#if TARGET_OS_TV
    #define AVIF_PLUGIN_TV 1
#else
    #define AVIF_PLUGIN_TV 0
#endif

#if AVIF_PLUGIN_MAC
#import <AppKit/AppKit.h>
#define Image   NSImage
#else
#import <UIKit/UIKit.h>
#define Image   UIImage
#endif

@implementation AVIFDataDecoder {
    avifDecoder *_idec;
}

- (void)dealloc {
    if (_idec) {
        avifDecoderDestroy(_idec);
        _idec = NULL;
    }
}

void sharedDecoderDeallocator(avifDecoder* d) {
    avifDecoderDestroy(d);
}

- (nullable Image *)incrementallyDecodeData:(NSData *)data {

    if (!_idec) {
        _idec = avifDecoderCreate();
        // Disable strict mode to keep some AVIF image compatible
        _idec->strictFlags = AVIF_STRICT_DISABLED;
        if (!_idec) {
            return nil;
        }

    }

    avifDecoderSetIOMemory(_idec, reinterpret_cast<const uint8_t *>(data.bytes), data.length);
    avifResult decodeResult = avifDecoderParse(_idec);

    if (decodeResult != AVIF_RESULT_OK && decodeResult != AVIF_RESULT_TRUNCATED_DATA) {
        NSLog(@"Failed to decode image: %s", avifResultToString(decodeResult));
        avifDecoderDestroy(_idec);
        _idec = NULL;
        return nil;
    }

    if (!_idec->allowProgressive) {
        NSLog(@"Progressive decoding is not allowed");
    }
    
    auto xForm = [[AVIFImageXForm alloc] init];

    // Static image
    if (_idec->imageCount == 1) {
        avifResult nextImageResult = avifDecoderNextImage(_idec);

        if (nextImageResult != AVIF_RESULT_OK) {
            NSLog(@"avifImageYUVToRGB %s", avifResultToString(nextImageResult));
            avifDecoderDestroy(_idec);
            _idec = NULL;
            return nil;
        }

        auto image = [xForm form:_idec scale:1];

        if (!image) {
            avifDecoderDestroy(_idec);
            _idec = NULL;
            return nil;
        }

        return image;
    } else if (_idec->imageCount > 1) {
        NSMutableArray<SDImageFrame *> *frames = [NSMutableArray array];
        while (avifDecoderNextImage(_idec) == AVIF_RESULT_OK) {
            @autoreleasepool {
                auto image = [xForm form:_idec scale:1];
                
                if (!image) {
                    avifDecoderDestroy(_idec);
                    _idec = NULL;
                    return nil;
                }
                
                NSTimeInterval duration = _idec->imageTiming.duration;
                SDImageFrame *frame = [SDImageFrame frameWithImage:image duration:duration];
                [frames addObject:frame];
            }
        }
        
        UIImage *animatedImage = [SDImageCoderHelper animatedImageWithFrames:frames];
        animatedImage.sd_imageLoopCount = 0;
        animatedImage.sd_imageFormat = SDImageFormatAVIF;
        
        return animatedImage;
    } else {
        NSLog(@"AVIF Data decoder: image is not already allocated... continue decoding...");
        avifDecoderDestroy(_idec);
        _idec = NULL;
        return nil;
    }
    avifDecoderDestroy(_idec);
    _idec = NULL;
    return nil;
}

- (nullable NSValue*)readSize:(nonnull NSData*)data error:(NSError *_Nullable * _Nullable)error {
    std::shared_ptr<avifDecoder> decoder(avifDecoderCreate(), sharedDecoderDeallocator);
    avifResult decodeResult = avifDecoderSetIOMemory(decoder.get(), reinterpret_cast<const uint8_t *>(data.bytes), data.length);
    if (decodeResult != AVIF_RESULT_OK) {
        *error = [[NSError alloc] initWithDomain:@"AVIF"
                                            code:500
                                        userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat: @"Failed to set IO: %s", avifResultToString(decodeResult)] }];
        return nil;
    }

    // Disable strict mode to keep some AVIF image compatible
    decoder->strictFlags = AVIF_STRICT_DISABLED;
    decodeResult = avifDecoderParse(decoder.get());
    if (decodeResult != AVIF_RESULT_OK) {
        NSLog(@"Failed to decode image: %s", avifResultToString(decodeResult));
        *error = [[NSError alloc] initWithDomain:@"AVIF"
                                            code:500
                                        userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat: @"readSize in AVIF failed with result: %s", avifResultToString(decodeResult)] }];
        return nil;
    }

    CGSize size = CGSizeMake(decoder->image->width, decoder->image->height);
#if TARGET_OS_OSX
    return [NSValue valueWithSize:size];
#else
    return [NSValue valueWithCGSize:size];
#endif
}

- (nullable NSValue*)readSizeFromPath:(nonnull NSString*)path error:(NSError *_Nullable * _Nullable)error {
    std::shared_ptr<avifDecoder> decoder(avifDecoderCreate(), sharedDecoderDeallocator);
    avifResult decodeResult = avifDecoderSetIOFile(decoder.get(), [path UTF8String]);
    if (decodeResult != AVIF_RESULT_OK) {
        *error = [[NSError alloc] initWithDomain:@"AVIF"
                                            code:500
                                        userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat: @"Failed to set IO: %s", avifResultToString(decodeResult)] }];
        return nil;
    }


    // Disable strict mode to keep some AVIF image compatible
    decoder->strictFlags = AVIF_STRICT_DISABLED;
    decodeResult = avifDecoderParse(decoder.get());
    if (decodeResult != AVIF_RESULT_OK) {
        *error = [[NSError alloc] initWithDomain:@"AVIF"
                                            code:500
                                        userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat: @"readSize in AVIF failed with result: %s", avifResultToString(decodeResult)] }];
        return nil;
    }

    CGSize size = CGSizeMake(decoder->image->width, decoder->image->height);

#if TARGET_OS_OSX
    return [NSValue valueWithSize:size];
#else
    return [NSValue valueWithCGSize:size];
#endif
}

- (nullable Image *)decode:(nonnull NSInputStream *)inputStream sampleSize:(CGSize)sampleSize maxContentSize:(NSUInteger)maxContentSize scale:(CGFloat)scale error:(NSError *_Nullable * _Nullable)error {
    try {
        if (scale < 1) {
            *error = [[NSError alloc] initWithDomain:@"AVIF"
                                                code:500
                                            userInfo:@{ NSLocalizedDescriptionKey: @"Scale cannot be less than 1" }];
            return nil;
        }
        NSInteger result;
        int bufferLength = 30196;
        uint8_t buffer[bufferLength];
        NSMutableData* data = [[NSMutableData alloc] init];
        [inputStream open];
        while((result = [inputStream read:buffer maxLength:bufferLength]) != 0) {
            if(result > 0) {
                [data appendBytes:&buffer[0] length:result];
                if (maxContentSize > 0 && data.length > maxContentSize) {
                    *error = [[NSError alloc] initWithDomain:@"AVIF"
                                                        code:500
                                                    userInfo:@{ NSLocalizedDescriptionKey: @"Content limit exceeded" }];
                    [inputStream close];
                    return nil;
                }
            } else {
                auto err = [inputStream streamError];
                if (err) {
                    *error = err;
                } else {
                    *error = [[NSError alloc] initWithDomain:@"AVIF"
                                                        code:500
                                                    userInfo:@{ NSLocalizedDescriptionKey: @"Input stream signalled unknown error" }];
                }
                [inputStream close];
                return nil;
            }
        }
        [inputStream close];
        std::shared_ptr<avifDecoder> decoder(avifDecoderCreate(), sharedDecoderDeallocator);

        avifResult decodeResult = avifDecoderSetIOMemory(decoder.get(), reinterpret_cast<const uint8_t *>(data.bytes), data.length);
        if (decodeResult != AVIF_RESULT_OK) {
            NSLog(@"Failed to decode image: %s", avifResultToString(decodeResult));
            *error = [[NSError alloc] initWithDomain:@"AVIF"
                                                code:500
                                            userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Decoding AVIF failed with: %s", avifResultToString(decodeResult)] }];
            return nil;
        }
        
        // Disable strict mode to keep some AVIF image compatible
        decoder->strictFlags = AVIF_STRICT_DISABLED;
        decoder->ignoreXMP = true;
        decoder->ignoreExif = true;
        int hwThreads = std::thread::hardware_concurrency();
        decoder->maxThreads = hwThreads;
        decodeResult = avifDecoderParse(decoder.get());
        if (decodeResult != AVIF_RESULT_OK) {
            NSLog(@"Failed to decode image: %s", avifResultToString(decodeResult));
            *error = [[NSError alloc] initWithDomain:@"AVIF"
                                                code:500
                                            userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Decoding AVIF failed with: %s", avifResultToString(decodeResult)] }];
            return nil;
        }
        
        if (!CGSizeEqualToSize(CGSizeZero, sampleSize)) {

            float imageAspectRatio = (float)decoder->image->width / (float)decoder->image->height;
            float canvasRatio = sampleSize.width / sampleSize.height;

            float resizeFactor = 1.0f;

            if (imageAspectRatio > canvasRatio) {
                resizeFactor = sampleSize.width / (float)decoder->image->width;
            } else {
                resizeFactor = sampleSize.height / (float)decoder->image->width;
            }

            if (!avifImageScale(decoder->image, (float)decoder->image->width*resizeFactor,
                                (float)decoder->image->height*resizeFactor, &decoder->diag)) {
                return nil;
            }
        }
        auto xForm = [[AVIFImageXForm alloc] init];
        
        // Static image
        if (decoder->imageCount == 1) {
            avifResult nextImageResult = avifDecoderNextImage(decoder.get());
            if (nextImageResult != AVIF_RESULT_OK) {
                NSLog(@"Failed to decode image: %s", avifResultToString(nextImageResult));
                *error = [[NSError alloc] initWithDomain:@"AVIF"
                                                    code:500
                                                userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Decoding AVIF failed with: %s", avifResultToString(nextImageResult)] }];
                return nil;
            }
            auto image = [xForm form:decoder.get() scale:scale];

            if (!image) {
                *error = [[NSError alloc] initWithDomain:@"AVIF" code:500 userInfo:@{ NSLocalizedDescriptionKey: @"Decoding AVIF has failed" }];
                return nil;
            }

            return image;
        } else if (decoder->imageCount < 1){
            NSLog(@"ImageCount < 1");
            return nil;
        } else {
            NSMutableArray<SDImageFrame *> *frames = [NSMutableArray array];
            while (avifDecoderNextImage(decoder.get()) == AVIF_RESULT_OK) {
                @autoreleasepool {
                    auto image = [xForm form:decoder.get() scale:scale];
                    /*CGImageRef imageRef = SDCreateCGImageFromAVIF(decoder->image);
                    if (!imageRef) {
                        continue;
                    }
                    Image *image = nil;
        #if AVIF_PLUGIN_MAC
                    image = [[NSImage alloc] initWithCGImage:imageRef size:CGSizeZero];
        #else
                    image = [UIImage imageWithCGImage:imageRef scale:scale orientation:UIImageOrientationUp];
        #endif*/
                    
                    if (!image) {
                        *error = [[NSError alloc] initWithDomain:@"AVIF" code:500 userInfo:@{ NSLocalizedDescriptionKey: @"Decoding AVIF has failed" }];
                        return nil;
                    }
                    
                    NSTimeInterval duration = decoder->imageTiming.duration; // Should use `decoder->imageTiming`, not the `decoder->duration`, see libavif source code
                    SDImageFrame *frame = [SDImageFrame frameWithImage:image duration:duration];
                    [frames addObject:frame];
                }
            }
        
            UIImage *animatedImage = [SDImageCoderHelper animatedImageWithFrames:frames];
            animatedImage.sd_imageLoopCount = 0;
            animatedImage.sd_imageFormat = SDImageFormatAVIF;
        
            return animatedImage;
        }
    } catch (std::bad_alloc &err) {
        *error = [[NSError alloc] initWithDomain:@"AVIF"
                                  code:500
                                  userInfo:@{ NSLocalizedDescriptionKey:
                                                  [NSString stringWithFormat:@"Memory corrupting while decoding: %s", err.what()] }];
        return nil;
    }
}

@end
