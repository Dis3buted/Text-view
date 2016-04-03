/*
     File: LineFoldingTextStorage.m
 Abstract: NSTextStorage subclass that adds NSAttachmentAttributeName for text with lineFoldingAttributeName.
  Version: 1.0
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2010 Apple Inc. All Rights Reserved.
 
 */

#import "LineFoldingTextStorage.h"
#import "LineFoldingTypesetter.h"
#import "LineFoldingTextAttachmentCell.h"

@implementation LineFoldingTextStorage
@synthesize lineFoldingEnabled = _lineFoldingEnabled;

static NSTextAttachment *sharedAttachment = nil;

+ (void)initialize {
    if ([self class] == [LineFoldingTextStorage class]) {
        LineFoldingTextAttachmentCell *cell = [[LineFoldingTextAttachmentCell alloc] initImageCell:nil];
        sharedAttachment = [[NSTextAttachment alloc] init];
        
        sharedAttachment.attachmentCell = cell;
        
    }
}

+ (NSTextAttachment *)attachment { return sharedAttachment; }

- (instancetype)init {
    self = [super init];

    if (nil != self) {
        _attributedString = [[NSTextStorage alloc] init];
    }

    return self;
}


// NSAttributedString primitives
- (NSString *)string { return _attributedString.string; }


- (NSDictionary *)attributesAtIndex:(NSUInteger)location effectiveRange:(NSRangePointer)range {
    NSDictionary *attributes = [_attributedString attributesAtIndex:location effectiveRange:range];

    if (_lineFoldingEnabled) {
        id value;
        NSRange effectiveRange;

        value = attributes[lineFoldingAttributeName];
        if (value && [value boolValue]) {
            [_attributedString attribute:lineFoldingAttributeName atIndex:location longestEffectiveRange:&effectiveRange inRange:NSMakeRange(0, _attributedString.length)];

            // We adds NSAttachmentAttributeName if in lineFoldingAttributeName
            if (location == effectiveRange.location) { // beginning of a folded range
                NSMutableDictionary *dict = [attributes mutableCopyWithZone:NULL];

                dict[NSAttachmentAttributeName] = [LineFoldingTextStorage attachment];

                attributes = dict;

                effectiveRange.length = 1;
            } else {
                ++(effectiveRange.location); --(effectiveRange.length);
            }

            if (range) *range = effectiveRange;
        }
    }

    return attributes;
}

// NSMutableAttributedString primitives
- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)str {
    [_attributedString replaceCharactersInRange:range withString:str];
    [self edited:NSTextStorageEditedCharacters range:range changeInLength:str.length - range.length];
}

- (void)setAttributes:(NSDictionary *)attrs range:(NSRange)range {
    [_attributedString setAttributes:attrs range:range];
    [self edited:NSTextStorageEditedAttributes range:range changeInLength:0];
}

// Attribute Fixing Overrides
- (void)fixAttributesInRange:(NSRange)range {
    [super fixAttributesInRange:range];

    // we want to avoid extending to the last paragraph separator
    [self enumerateAttribute:lineFoldingAttributeName inRange:range options:0 usingBlock:^(id value, NSRange range, BOOL *stop) {
        if (value && (range.length > 1)) {
            NSUInteger paragraphStart, paragraphEnd, contentsEnd;
            
            [self.string getParagraphStart:&paragraphStart end:&paragraphEnd contentsEnd:&contentsEnd forRange:range];
            
            if ((NSMaxRange(range) == paragraphEnd) && (contentsEnd < paragraphEnd)) {
                [self removeAttribute:lineFoldingAttributeName range:NSMakeRange(contentsEnd, paragraphEnd - contentsEnd)];
            }
        }
    }];
}

@end
