//
//  NSData+ImageContentType.h
//  avif
//
//  Created by Eom SeHwan on 1/8/25.
//

#ifndef NSData_ImageContentType_h
#define NSData_ImageContentType_h

#if __has_include(<SDWebImage/SDWebImage.h>)
#import <SDWebImage/NSData+ImageContentType.h>
#else
#import "../SDSources/NSData+ImageContentType.h"
#endif

static const SDImageFormat SDImageFormatAVIF = 11;

#endif
