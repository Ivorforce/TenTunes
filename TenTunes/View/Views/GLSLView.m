//
//  GLSLView.m
//  TenTunes
//
//  Created by Lukas Tenbrink on 07.09.18.
//  Copyright © 2018 ivorius. All rights reserved.
//

#import "GLSLView.h"
#import <OpenGL/glu.h>

@implementation GLSLView

- (void)awakeFromNib
{
    [self setStartDate: [NSDate date]];
    
    int error;
    
    // 1. Create a context with opengl pixel format
    NSOpenGLPixelFormatAttribute pixelFormatAttributes[] =
    {
        NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion3_2Core,
        NSOpenGLPFAColorSize    , 24                           ,
        NSOpenGLPFAAlphaSize    , 8                            ,
        NSOpenGLPFADoubleBuffer ,
        NSOpenGLPFAAccelerated  ,
        NSOpenGLPFANoRecovery   ,
        0
    };
    NSOpenGLPixelFormat *pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:pixelFormatAttributes];
    super.pixelFormat = pixelFormat;
    
    // 2. Make the context current
    [[self openGLContext] makeCurrentContext];

    [super awakeFromNib];
    
    if ((error = glGetError()) != 0) { NSLog(@"Setup GL Error: %d", error); }

    // 3. Define and compile vertex and fragment shaders
    [self setupShaders];
    
    // 6. Upload vertices 
    GLfloat vertexData[]= { -1,-1,0.0,1.0,
        -1, 1,0.0,1.0,
        1, 1,0.0,1.0,
        1,-1,0.0,1.0 }
    ;
    glGenVertexArrays(1, &vertexArrayObject);
    glBindVertexArray(vertexArrayObject);
    
    glGenBuffers(1, &vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, 4*8*sizeof(GLfloat), vertexData, GL_STATIC_DRAW);
    
    glEnableVertexAttribArray((GLuint)positionAttribute);
    glVertexAttribPointer((GLuint)positionAttribute, 4, GL_FLOAT, GL_FALSE, 4*sizeof(GLfloat), 0);
    
    if ((error = glGetError()) != 0) { NSLog(@"Setup End GL Error: %d", error); }
}

- (void)setupShaders {
    int error;
    
    GLuint  vs;
    GLuint  fs;
    NSString *fragmentPath = [[NSBundle mainBundle] pathForResource:@"visualizer" ofType:@"fs"];
    const char *fss = [[NSString stringWithContentsOfFile:fragmentPath encoding:NSUTF8StringEncoding error:nil] cStringUsingEncoding:NSUTF8StringEncoding];
    
    NSString *vertexPath = [[NSBundle mainBundle] pathForResource:@"visualizer" ofType:@"vs"];
    const char *vss= [[NSString stringWithContentsOfFile:vertexPath encoding:NSUTF8StringEncoding error:nil] cStringUsingEncoding:NSUTF8StringEncoding];
    
    vs = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vs, 1, &vss, NULL);
    glCompileShader(vs);
    if (![self checkCompiled: vs]) { return; }
    
    fs = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fs, 1, &fss, NULL);
    glCompileShader(fs);
    if (![self checkCompiled: fs]) { return; }
    
    // 4. Attach the shaders
    shaderProgram = glCreateProgram();
    glAttachShader(shaderProgram, vs);
    glAttachShader(shaderProgram, fs);
    glLinkProgram(shaderProgram);
    
    if ((error = glGetError()) != 0) { NSLog(@"Shader Link GL Error: %d", error); }
    if (![self checkLinked: shaderProgram]) { return; }

    // 5. Get pointers to uniforms and attributes
    positionUniform = glGetUniformLocation(shaderProgram, "p");
    positionAttribute = glGetAttribLocation(shaderProgram, "position");
    
    timeAttribute = glGetUniformLocation(shaderProgram, "time");
    resolutionAttribute = glGetUniformLocation(shaderProgram, "resolution");
    
    if ((error = glGetError()) != 0) { NSLog(@"Attrib Link GL Error: %d", error); }
    
    glDeleteShader(vs);
    glDeleteShader(fs);
}

- (BOOL)checkCompiled:(GLint)obj {
    GLint isCompiled = 0;
    glGetShaderiv(obj, GL_COMPILE_STATUS, &isCompiled);
    if(isCompiled == GL_FALSE)
    {
        GLint maxLength = 0;
        glGetShaderiv(obj, GL_INFO_LOG_LENGTH, &maxLength);
        
        GLchar *log = (GLchar *)malloc(maxLength);
        glGetShaderInfoLog(obj, maxLength, &maxLength, log);
        printf("Shader Compile Error: \n%s\n", log);
        free(log);
        
        glDeleteShader(obj);
        return NO;
    }
    
    return YES;
}

- (BOOL)checkLinked:(GLint)obj {
    int maxLength = 0;
    glGetProgramiv(obj, GL_INFO_LOG_LENGTH, &maxLength);
    if (maxLength > 0)
    {
        GLchar *log = (GLchar *)malloc(maxLength);
        glGetProgramInfoLog(obj, maxLength, &maxLength, log);
        printf("Shader Program Error: \n%s\n", log);
        free(log);
        
        return NO;
    }
    
    return YES;
}

- (void)drawFrame {
    glUseProgram(shaderProgram);
    
    glUniform1f(timeAttribute, -[[self startDate] timeIntervalSinceNow]);
    glUniform2f(resolutionAttribute, _bounds.size.width, _bounds.size.height);

    [self uploadUniforms];
    
    GLfloat p[]={0,0};
    glUniform2fv(positionUniform, 1, (const GLfloat *)&p);
    glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
}

- (GLint)findUniform:(NSString *)name {
    return glGetUniformLocation(shaderProgram, [name cStringUsingEncoding:NSASCIIStringEncoding]);
}

- (void)uploadUniforms {
    
}

@end
