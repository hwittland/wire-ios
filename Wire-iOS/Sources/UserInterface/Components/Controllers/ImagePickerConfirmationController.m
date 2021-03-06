// 
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
// 
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// 
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
// 


#import "ImagePickerConfirmationController.h"

#import <AssetsLibrary/AssetsLibrary.h>
#import <MobileCoreServices/MobileCoreServices.h>

#import "Constants.h"
#import "ConfirmImageViewController.h"
#import "UIView+PopoverBorder.h"
#import "UIImagePickerController+GetImage.h"
#import "FLAnimatedImage.h"
#import "FLAnimatedImageView.h"
#import "SketchViewController.h"
#import "MediaAsset.h"



@interface ImagePickerConfirmationController ()

/// We need to store this reference to close the @c SketchViewController
@property (nonatomic) UIImagePickerController *presentingPickerController;

@end

@interface ImagePickerConfirmationController (SketchViewControllerDelegate) <SketchViewControllerDelegate>
@end

@implementation ImagePickerConfirmationController

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    self.presentingPickerController = picker;
    
    [self assetPreviewFromMediaInfo:info resultBlock:^(id image) {
        @weakify(self);
        
        if (picker.sourceType == UIImagePickerControllerSourceTypePhotoLibrary) {
            ConfirmImageViewController *confirmImageViewController = [[ConfirmImageViewController alloc] init];
            confirmImageViewController.modalPresentationStyle = UIModalPresentationOverCurrentContext;
            confirmImageViewController.image = image;
            confirmImageViewController.previewTitle = self.previewTitle;
            confirmImageViewController.editButtonVisible = YES;
            
            if (IS_IPAD) {
                [confirmImageViewController.view setPopoverBorderEnabled:YES];
            }
            
            confirmImageViewController.onCancel = ^{
                [picker dismissViewControllerAnimated:YES completion:nil];
            };
            
            confirmImageViewController.onConfirm = ^{
                @strongify(self);
                
                [UIImagePickerController imageDataFromMediaInfo:info resultBlock:^(NSData *imageData) {
                    if (imageData != nil) {
                        self.imagePickedBlock(imageData);
                    }
                }];
            };
            
            confirmImageViewController.onEdit = ^{
                [picker dismissViewControllerAnimated:YES completion:nil];
                
                SketchViewController *sketchViewController = [[SketchViewController alloc] init];
                sketchViewController.sketchTitle = NSLocalizedString(@"image.edit_image", @"");
                sketchViewController.delegate = self;
                
                [picker presentViewController:sketchViewController animated:YES completion:^{
                    sketchViewController.canvasBackgroundImage = image;
                }];
            };
            
            [picker presentViewController:confirmImageViewController animated:YES completion:nil];
            [picker setNeedsStatusBarAppearanceUpdate];
        }
    }];
}

- (void)assetPreviewFromMediaInfo:(NSDictionary *)info resultBlock:(void (^)(id media))resultBlock
{
    NSString *assetUTI = [self UTIFromAssetURL:info[UIImagePickerControllerReferenceURL]];
    
    if ([assetUTI isEqualToString:(id)kUTTypeGIF]) {
        [UIImagePickerController imageDataFromMediaInfo:info resultBlock:^(NSData *imageData) {
            resultBlock([[FLAnimatedImage alloc] initWithAnimatedGIFData:imageData]);
        }];
    } else {
        [UIImagePickerController previewImageFromMediaInfo:info resultBlock:^(UIImage *image) {
            resultBlock(image);
        }];
    }
}

- (NSString *)UTIFromAssetURL:(NSURL *)assetURL
{
    NSString *extension = [assetURL pathExtension];
    return (NSString *)CFBridgingRelease(UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension,(__bridge CFStringRef)extension , NULL));
}


@end

@implementation ImagePickerConfirmationController (SketchViewControllerDelegate)

- (void)sketchViewControllerDidCancel:(SketchViewController *)controller
{
    [self.presentingPickerController dismissViewControllerAnimated:YES completion:nil];
}

- (void)sketchViewController:(SketchViewController *)controller didSketchImage:(UIImage *)image
{
    @weakify(self);
    [self.presentingPickerController dismissViewControllerAnimated:YES completion:^{
        @strongify(self);
        
        ConfirmImageViewController *confirmImageViewController = [[ConfirmImageViewController alloc] init];
        confirmImageViewController.modalPresentationStyle = UIModalPresentationOverCurrentContext;
        confirmImageViewController.image = image;
        confirmImageViewController.previewTitle = self.previewTitle;
        
        if (IS_IPAD) {
            [confirmImageViewController.view setPopoverBorderEnabled:YES];
        }
        
        confirmImageViewController.onCancel = ^{
            [self.presentingPickerController dismissViewControllerAnimated:YES completion:nil];
        };
        
        confirmImageViewController.onConfirm = ^{
            self.imagePickedBlock(UIImagePNGRepresentation(image));
        };
        
        [self.presentingPickerController presentViewController:confirmImageViewController animated:YES completion:nil];
        [self.presentingPickerController setNeedsStatusBarAppearanceUpdate];
    }];
}

@end
