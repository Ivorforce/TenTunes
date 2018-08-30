//
//  TagLibFile.mm
//  TenTunes
//
//  Created by Lukas Tenbrink on 30.08.2018.
//  Copyright © 2018 Lukas Tenbrink. All rights reserved.
//

#import "TagLibFile.h"

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdocumentation-deprecated-sync"
#pragma GCC diagnostic ignored "-Wdocumentation"
#pragma GCC diagnostic ignored "-Wmacro-redefined"
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"

#import <fileref.h>
#import <tag.h>
#import <tpropertymap.h>

#import <rifffile.h>
#import <aifffile.h>
#import <wavfile.h>
#import <mpegfile.h>
#import <flacfile.h>
#import <trueaudiofile.h>

#include <id3v2tag.h>
#include <id3v2frame.h>
#include <id3v2header.h>
#include <attachedpictureframe.h>
#include <textidentificationframe.h>
#include <commentsframe.h>
#include <mp4tag.h>
//#include <tmap.h>


#include <id3v1tag.h>

#include <iostream>

#import <AVFoundation/AVFoundation.h>

#pragma GCC diagnostic pop

inline NSString *TagLibStringToNS(const TagLib::String &tagString) {
    if (tagString == TagLib::ByteVector::null)
        return nil;
    return [NSString stringWithUTF8String:tagString.toCString(true)];
}

inline const TagLib::String TagLibStringFromNS(NSString *string) {
    if (string == nil)
        return TagLib::ByteVector::null;
    return TagLib::String([string UTF8String], TagLib::String::UTF8);
}

#pragma mark File

@interface TagLibFile ()

@property TagLib::FileRef fileRef;

- (TagLib::Tag *)tag;

- (void)setID3:(NSString *)key text:(NSString *)text;

@end

@implementation TagLibFile

-(instancetype)initWithURL:(NSURL * _Nonnull)url {
    self = [super init];
    if (self) {
        TagLib::FileRef f(url.fileSystemRepresentation);
        
        if (f.isNull()) {
            return nil;
        }
        
        [self setFileRef:f];
    }
    return self;
}

- (TagLib::Tag *)tag {
    return _fileRef.tag();
}

#pragma mark Generic

- (void)setTitle:(NSString *)title {
    [self tag]->setTitle(TagLibStringFromNS(title));
}

- (NSString *)title {
    return TagLibStringToNS([self tag]->title());
}

- (void)setArtist:(NSString *)artist {
    [self tag]->setArtist(TagLibStringFromNS(artist));
}

- (NSString *)artist {
    return TagLibStringToNS([self tag]->title());
}

- (void)setAlbum:(NSString *)album {
    [self tag]->setAlbum(TagLibStringFromNS(album));
}

- (NSString *)album {
    return TagLibStringToNS([self tag]->album());
}

- (void)setBand:(NSString *)band {
    [self setID3:AVMetadataID3MetadataKeyBand text:band];
}

- (NSString *)band {
    return [self getID3v2Text:AVMetadataID3MetadataKeyBand];
}

- (void)setRemixArtist:(NSString *)remixArtist {
    [self setID3:AVMetadataID3MetadataKeyModifiedBy text:remixArtist];
}

- (NSString *)remixArtist {
    return [self getID3v2Text:AVMetadataID3MetadataKeyModifiedBy];
}

- (void)setGenre:(NSString *)genre {
    [self tag]->setGenre(TagLibStringFromNS(genre));
}

- (NSString *)genre {
    return TagLibStringToNS([self tag]->genre());
}

+ (int) priority:(TagLib::ID3v2::AttachedPictureFrame::Type) type {
    switch (type) {
        case TagLib::ID3v2::AttachedPictureFrame::FrontCover:
            return 0;
        case TagLib::ID3v2::AttachedPictureFrame::FileIcon:
            return 1;
        case TagLib::ID3v2::AttachedPictureFrame::OtherFileIcon:
            return 2;
        case TagLib::ID3v2::AttachedPictureFrame::Illustration:
            return 3;
        case TagLib::ID3v2::AttachedPictureFrame::PublisherLogo:
            return 4;
        default:
            return 100;
    }
}

- (void)setImage:(NSImage *)image {
    // DON'T remove existing images. Each have different attributes. Only remove the one we're setting
}

- (NSImage *)image {
    auto tag = [self id3v2Tag: false];
    if (tag) {
        TagLib::ID3v2::AttachedPictureFrame::Type currentPictureType = TagLib::ID3v2::AttachedPictureFrame::Type::Other;
        NSImage *image = nil;
        
        TagLib::ID3v2::FrameList::ConstIterator it = tag->frameList().begin();
        for(; it != tag->frameList().end(); it++) {
            if(auto picture_frame = dynamic_cast<TagLib::ID3v2::AttachedPictureFrame *>(*it)) {
                if (image == nil || ([TagLibFile priority: picture_frame->type()] < [TagLibFile priority: currentPictureType])) {
                    
                    TagLib::ByteVector imgVector = picture_frame->picture();
                    NSData *data = [NSData dataWithBytes:imgVector.data() length:imgVector.size()];
                    image = [[NSImage alloc] initWithData: data];
                    currentPictureType = picture_frame->type();
                }
            }
        }
        
        return image;
    }
    
    return nil;
}

- (void)setInitialKey:(NSString *)initialKey {
    [self setID3:AVMetadataID3MetadataKeyInitialKey text:initialKey];
}

- (NSString *)initialKey {
    return [self getID3v2Text:AVMetadataID3MetadataKeyInitialKey];
}

- (void)setBpm:(NSString *)bpm {
    [self setID3:AVMetadataID3MetadataKeyBeatsPerMinute text:bpm];
}

- (NSString *)bpm {
    return [self getID3v2Text:AVMetadataID3MetadataKeyBeatsPerMinute];
}

- (void)setComments:(NSString *)comments {
    [self tag]->setComment(TagLibStringFromNS(comments));
}

- (NSString *)comments {
    return TagLibStringToNS([self tag]->comment());
}

- (void)setYear:(unsigned int)year {
    [self tag]->setYear(year);
}

- (unsigned int)year {
    return [self tag]->year();
}

- (void)setTrackNumber:(unsigned int)trackNumber {
    [self tag]->setTrack(trackNumber);
}

- (unsigned int)trackNumber {
    return [self tag]->track();
}

// ID3v1 is auto-supported with taglib's default setters and getters
#pragma mark ID3v2

- (TagLib::ID3v2::Tag *)id3v2Tag:(BOOL)create {
    // TODO Create
    if (TagLib::MPEG::File *file = dynamic_cast<TagLib::MPEG::File *>(_fileRef.file())) {
        if (file->hasID3v2Tag()) {
            return file->ID3v2Tag();
        }
    }
    else if (TagLib::RIFF::AIFF::File *file = dynamic_cast<TagLib::RIFF::AIFF::File *>(_fileRef.file())) {
        if (file->hasID3v2Tag()) {
            return file->tag();
        }
    }
    else if (TagLib::RIFF::WAV::File *file = dynamic_cast<TagLib::RIFF::WAV::File *>(_fileRef.file())) {
        if (file->hasID3v2Tag()) {
            return file->ID3v2Tag();
        }
    }
    else if (TagLib::FLAC::File *file = dynamic_cast<TagLib::FLAC::File *>(_fileRef.file())) {
        if (file->hasID3v2Tag()) {
            return file->ID3v2Tag();
        }
    }
    else if (TagLib::TrueAudio::File *file = dynamic_cast<TagLib::TrueAudio::File *>(_fileRef.file())) {
        if (file->hasID3v2Tag()) {
            return file->ID3v2Tag();
        }
    }

    return nil;
}

- (NSString *)getID3v2Text:(NSString *)key {
    auto tag = [self id3v2Tag: false];
    if (tag) {
        return [TagLibFile getID3TextIn:tag forKey:key];
    }
    return nil;
}

+ (NSString *)getID3TextIn:(TagLib::ID3v2::Tag *)tag forKey:(NSString *)key {
    TagLib::ID3v2::FrameList::ConstIterator it = tag->frameList().begin();
    for(; it != tag->frameList().end(); it++) {
        if(auto text_frame = dynamic_cast<TagLib::ID3v2::TextIdentificationFrame *>(*it)) {
            auto frame_id = text_frame->frameID();
            
            if (frame_id == key.UTF8String) {
                return TagLibStringToNS(text_frame->toString());
            }
        }
    }
    
    return nil;
}

- (void)setID3:(NSString *)key text:(NSString *)text {
    auto tag = [self id3v2Tag: true];
    if (tag) {
        [TagLibFile replaceFrameIn:tag key:key text:text];
    }
    else {
        NSLog(@"Failed to create ID3v2 tag for file");
    }
}

+ (void)replaceFrameIn:(TagLib::ID3v2::Tag *)tag key:(NSString *)key text:(NSString *)text {
    // Remove existing
    tag->removeFrames(key.UTF8String);
    
    // Add new
    if (text != nil) {
        TagLib::String tText = TagLibStringFromNS(text);
        TagLib::ID3v2::TextIdentificationFrame *frame = new TagLib::ID3v2::TextIdentificationFrame(key.UTF8String, TagLib::String::UTF8);
        frame->setText(tText);
        tag->addFrame(frame);
    }
}

#pragma mark I/O

-(BOOL)write:(NSError *__autoreleasing *)error {
    if (!_fileRef.save()) {
        @throw [NSException exceptionWithName:@"FileWriteException"
                                       reason:@"File could not be saved"
                                     userInfo:nil];
    }
    
    return YES;
}

@end
