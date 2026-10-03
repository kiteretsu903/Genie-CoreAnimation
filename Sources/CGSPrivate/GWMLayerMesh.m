#import "GWMLayerMesh.h"
#import <objc/message.h>
// Runtime-only CA mesh ABI, documented by Bartosz Ciechanowski:
// https://ciechanow.ski/mesh-transforms/ . No upstream implementation copied.
typedef struct { CGFloat x,y,z; } GWMPoint3D;
typedef struct { CGPoint from; GWMPoint3D to; } GWMVertex;
typedef struct { unsigned int indices[4]; float weights[4]; } GWMFace;
static SEL factory(void) { return NSSelectorFromString(@"meshTransformWithVertexCount:vertices:faceCount:faces:depthNormalization:"); }
BOOL GWMLayerMeshAvailable(void) {
    return [NSClassFromString(@"CAMeshTransform") respondsToSelector:factory()] &&
        [CALayer instancesRespondToSelector:NSSelectorFromString(@"setMeshTransform:")];
}
id GWMCreateLayerMesh(const CGPoint *from,const CGPoint *to,NSUInteger columns,NSUInteger rows) {
    if (!GWMLayerMeshAvailable() || columns<2 || rows<2 || columns>128 || rows>128) return nil;
    NSUInteger count=columns*rows, facesCount=(columns-1)*(rows-1);
    GWMVertex *vertices=calloc(count,sizeof(GWMVertex));
    GWMFace *faces=calloc(facesCount,sizeof(GWMFace));
    if (!vertices || !faces) { free(vertices);free(faces);return nil; }
    for (NSUInteger i=0;i<count;i++) vertices[i]=(GWMVertex){from[i],{to[i].x,to[i].y,0}};
    for(NSUInteger y=0;y<rows-1;y++) for(NSUInteger x=0;x<columns-1;x++) {
        unsigned int a=(unsigned int)(y*columns+x);
        faces[y*(columns-1)+x]=(GWMFace){{a,a+1,a+(unsigned int)columns+1,a+(unsigned int)columns},{0,0,0,0}};
    }
    id mesh=nil;
    @try {
        id (*make)(id,SEL,NSUInteger,const GWMVertex *,NSUInteger,const GWMFace *,NSString *)=(void *)objc_msgSend;
        mesh=make(NSClassFromString(@"CAMeshTransform"),factory(),count,vertices,facesCount,faces,@"none");
        // Match the existing triangle mesh; don't smooth/control-point-subdivide it.
        id mutable=[mesh mutableCopy];
        if ([mutable respondsToSelector:NSSelectorFromString(@"setSubdivisionSteps:")]) {
            [mutable setValue:@0 forKey:@"subdivisionSteps"];
            id flat=[mutable copy];
#if !__has_feature(objc_arc)
            [mutable release];mesh=[flat autorelease];
#else
            mesh=flat;
#endif
        } else {
#if !__has_feature(objc_arc)
            [mutable release];
#endif
        }
    } @catch(NSException *exception) { mesh=nil; }
    free(vertices);free(faces);return mesh;
}
BOOL GWMApplyLayerMesh(CALayer *layer,id mesh) {
    @try { [layer setValue:mesh forKey:@"meshTransform"];return YES; }
    @catch(NSException *exception) { return NO; }
}
BOOL GWMAnimateLayerMesh(CALayer *layer,NSArray *values,NSArray<NSNumber *> *times,CFTimeInterval duration,NSString *key) {
    @try {
        CAKeyframeAnimation *motion=[CAKeyframeAnimation animationWithKeyPath:@"meshTransform"];
        motion.values=values;motion.keyTimes=times;motion.duration=duration;
        motion.calculationMode=kCAAnimationLinear;
        motion.timingFunction=[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
        [layer addAnimation:motion forKey:key];return YES;
    } @catch(NSException *exception) { return NO; }
}
