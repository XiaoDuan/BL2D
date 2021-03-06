//
//  BL2DGraphics.m
//  Basic2DEngine
//
//  Copyright 2010 Scott Lawrence. All rights reserved.
//

/*
 Copyright (c) 2010 Scott Lawrence
 
 (MIT License)
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */ 

#import "BL2DGraphics.h"
@interface BL2DGraphics()
- (void) computePercentages;
- (void) loadPng:(NSString *)fn;
@end

#define kPixellyScaleups	(1)

@implementation BL2DGraphics

@synthesize glHandle;
@synthesize pxHeight, pxWidth;
@synthesize tilesWide, tilesHigh;

#pragma mark -
#pragma mark classy stuff

- (id) initWithPNG:(NSString *)filename 
		 tilesWide:(int)across
		 tilesHigh:(int)slurp
{
	self = [super init];
	if (self)
    {
		image_width = 0;
		image_height = 0;
		tilesWide = across;
		tilesHigh = slurp;
		glHandle = 0;
		percentsW = NULL;
		percentsH = NULL;
		
		[self loadPng:filename];
		[self computePercentages];
		
		pxWidth = image_width / tilesWide;
		pxHeight = image_height / tilesHigh;
	}
	return self;
}

- (void)dealloc
{
	// free up our allocated space
	if( percentsW ) free( percentsW );
	if( percentsH ) free( percentsH );
	
	// and free the image texture
	glDeleteTextures( 1, &glHandle );
	
	[super dealloc];
}

#pragma mark -
#pragma mark the important stuff

- (void)loadPng:(NSString *)fn
{
	// ref http://iphonedevelopment.blogspot.com/2009/05/opengl-es-from-ground-up-part-6_25.html
	
	// GL prep
	glEnable(GL_TEXTURE_2D);
    glEnable(GL_BLEND);
    glBlendFunc(GL_ONE, GL_SRC_COLOR);
	//	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA); // use for png
	
	// make texture name
	GLuint texture[1];
	glGenTextures(1, &texture[0]);
	glBindTexture(GL_TEXTURE_2D, texture[0]);
	
#ifdef kPixellyScaleups	// for pixelly scale-ups
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);	
#else
	// configure (for smooth scaleups)
	glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR); 
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
#endif

	// load image
	NSString *path = [[NSBundle mainBundle] pathForResource:fn ofType:@"png"];
    NSData *texData = [[NSData alloc] initWithContentsOfFile:path];
    UIImage *image = [[UIImage alloc] initWithData:texData];
    if (image == nil) {
        NSLog(@"Failed load!");
		glDisable(GL_TEXTURE_2D);
		glDisable(GL_BLEND);
		glBindTexture(GL_TEXTURE_2D, 0);		
		return;
	}
	
    GLuint width = CGImageGetWidth(image.CGImage);
    GLuint height = CGImageGetHeight(image.CGImage);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    void *imageData = malloc( height * width * 4 );
    CGContextRef context = CGBitmapContextCreate( imageData, width, height, 8, 4 * width, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big );
    CGColorSpaceRelease( colorSpace );
    CGContextClearRect( context, CGRectMake( 0, 0, width, height ) );
    CGContextTranslateCTM( context, 0, height - height );
    CGContextDrawImage( context, CGRectMake( 0, 0, width, height ), image.CGImage );
	
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, imageData);
	
    CGContextRelease(context);
	
    free(imageData);
    [image release];
    [texData release];
	
	glDisable(GL_TEXTURE_2D);
    glDisable(GL_BLEND);
	glBindTexture(GL_TEXTURE_2D, 0);


	// store it aside	
	image_width = width;
	image_height = height;
	
	glHandle = texture[0];	
}

- (void) computePercentages
{
	// horizontals/verticals: (this might be premature optimization.)
	//  take image_width/tilesWide - this number +1 is the number of entries to alloc
	percentsW = (float *)calloc( tilesWide+1, sizeof( float ));	
	for( int i=0 ; i<tilesWide+1 ; i++ ) 
	{
		percentsW[i] = (float)i/(float) tilesWide;
	}

	percentsH = (float *)calloc( tilesHigh+1 , sizeof( float ));	
	for( int i=0 ; i<tilesHigh+1 ; i++ ) 
	{
		percentsH[i] = (float)i/(float) tilesHigh;
	}
}


#pragma mark -
#pragma mark gl rendering helpers

- (void) glActivate
{	
	glEnable(GL_TEXTURE_2D);
	glBindTexture(GL_TEXTURE_2D, glHandle);	
}

- (void) glDeactivate
{
	glDisable(GL_TEXTURE_2D);
	glBindTexture(GL_TEXTURE_2D, 0);	
}

- (int) getXTileForIndex:(int)index
{
	return index % tilesWide;
}

- (int) getYTileForIndex:(int)index
{
	int nTiles = tilesHigh * tilesWide;
	if( index >= ( nTiles )) index = index % nTiles;
	
	return index / tilesWide;
}


#pragma mark -
#pragma mark rendering

- (void) fillQuadIn:(GLfloat *)buffer forTile:(int)index
{
	int xTile = [self getXTileForIndex:index];
	int yTile = [self getYTileForIndex:index];
	
	// top left
	buffer[0] = percentsW[xTile];
	buffer[1] = percentsH[yTile];
	
	// bottom left
	buffer[2] = percentsW[xTile];
	buffer[3] = percentsH[yTile+1];
	
	// top right
	buffer[4] = percentsW[xTile+1];
	buffer[5] = percentsH[yTile];
	
	// bottom right
	buffer[6] = percentsW[xTile+1];
	buffer[7] = percentsH[yTile+1];

	// bottom right (repeated)
	buffer[8] = percentsW[xTile+1];
	buffer[9] = percentsH[yTile+1];
	
}


- (void) setupBufferForTile:(int)index into:(GLfloat *)buffer	/* [15] */
{
	if( !buffer ) return;

	// generate a backwards-n format	
	if( index == kRenderEntireImage )
	{
		// top left
		buffer[0] = 0.0;	buffer[1] = 0.0;

		// bottom left
		buffer[2] = 0.0;	buffer[3] = 1.0;

		// top right
		buffer[4] = 1.0;	buffer[5] = 0.0;

		// bottom right
		buffer[6] = 1.0;	buffer[7] = 1.0;
		buffer[8] = 1.0;	buffer[9] = 1.0;
		
		return;
	}

	// otherwise the index is pseudovalid
	[self fillQuadIn:buffer forTile:index];
}

- (void) setupSpriteBuffer:(GLfloat *)buffer flipX:(BOOL)fx flipY:(BOOL)fy
{	
	GLfloat w = (GLfloat) pxWidth;
	GLfloat h = (GLfloat) pxHeight;
	
	/* this is the nice way to look at this...
	buffer[0] = 0.0;	buffer[1] = 0.0;	buffer[2] = 0.0;
	buffer[3] = 0.0;	buffer[4] = h;		buffer[5] = 0.0;
	buffer[6] = w;		buffer[7] = 0.0;	buffer[8] = 0.0;
	buffer[9] = w;		buffer[10] = h;		buffer[11] = 0.0;
	 */
	
	// but this way makes more sense, code-wise
	if( fx ) {
		buffer[0] = buffer[3] = w;
		buffer[6] = buffer[9] = 0.0;
	} else {
		buffer[0] = buffer[3] = 0.0;
		buffer[6] = buffer[9] = w;
	}
	
	if( fy ) {
		buffer[1] = buffer[7] = h;
		buffer[4] = buffer[10] = 0.0;
	} else {
		buffer[1] = buffer[7] = 0.0;
		buffer[4] = buffer[10] = h;
	}
	
	// Z
	buffer[2] = buffer[5] = buffer[8] = buffer[11] = 0.0;
	
	// final point
	buffer[12] = buffer[9];
	buffer[13] = buffer[10];
	buffer[14] = buffer[11];
}

- (void) renderSingle:(int)index flipX:(BOOL)fx flipY:(BOOL)fy
{
	GLfloat textureBuffer[10];
	GLfloat spriteBuffer[15];

	[self setupBufferForTile:index into:textureBuffer];
	[self setupSpriteBuffer:spriteBuffer flipX:fx flipY:fy ];

	[self glActivate];
	
	// place it on the gl canvas
	
	glEnable(GL_TEXTURE_2D);
	glDisable(GL_DEPTH_TEST);
	
	glEnableClientState(GL_TEXTURE_COORD_ARRAY);
	glTexCoordPointer(2, GL_FLOAT, 0, textureBuffer );
	glEnableClientState(GL_VERTEX_ARRAY);
	glVertexPointer(3, GL_FLOAT, 0, spriteBuffer );
	
	// set it up so we can do transparency
	
	glColor4f( 1.0, 1.0, 1.0, 1.0 );
	glEnable(GL_BLEND);
	//	glBlendFunc (GL_ONE, GL_SRC_COLOR);
	glBlendFunc (GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
	
	glDisable(GL_BLEND);
	glColor4f( 1.0, 1.0, 1.0, 1.0 );
	
	glDisableClientState(GL_VERTEX_ARRAY);
	glDisableClientState(GL_TEXTURE_COORD_ARRAY);

	// unbind
	[self glDeactivate];
}


- (void)renderSolidAlpha:(GLfloat)alpha  R:(GLfloat)r G:(GLfloat)g B:(GLfloat)b
{
	GLfloat buffer[12];
	[self setupSpriteBuffer: buffer flipX:NO flipY:NO];
	
	glEnable(GL_TEXTURE_2D);
	glDisable(GL_DEPTH_TEST);
	
	glEnableClientState(GL_VERTEX_ARRAY);
	glVertexPointer(3, GL_FLOAT, 0, buffer);
	
	// set it up so we can do transparency
	glColor4f( r, 0.0, b, alpha );
	glEnable(GL_BLEND);
	glBlendFunc (GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
	
	glDisable( GL_BLEND );
	glDisableClientState(GL_VERTEX_ARRAY);	
}

@end
