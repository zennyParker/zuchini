#import "RuntimeBridge.h"
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#include <dlfcn.h>
#include <cmath>
#include <vector>
#include <map>
#include <string>
#include <algorithm>
#include <cstring>

namespace {
using P = void*;
struct Vec3 { float x,y,z; };
struct Quaternion { float x,y,z,w; };
struct API {
    P (*domain_get)();
    const P* (*domain_get_assemblies)(P,size_t*);
    P (*assembly_get_image)(P);
    const char* (*image_get_name)(P);
    P (*class_from_name)(P,const char*,const char*);
    P (*class_get_parent)(P);
    P (*class_get_methods)(P,P*);
    const char* (*method_get_name)(P);
    uint32_t (*method_get_param_count)(P);
    P (*method_get_param)(P,uint32_t);
    char* (*type_get_name)(P);
    void (*free)(P);
    P (*class_get_type)(P);
    P (*type_get_object)(P);
    P (*object_get_class)(P);
    P (*object_unbox)(P);
    P (*runtime_invoke)(P,P,P*,P*);
    uintptr_t (*array_length)(P);
    P (*class_get_field_from_name)(P,const char*);
    void (*field_get_value)(P,P,P);
    int32_t (*class_value_size)(P,uint32_t*);
    uint32_t (*gchandle_new)(P,bool);
    P (*gchandle_get_target)(uint32_t);
    void (*gchandle_free)(uint32_t);
    P (*thread_current)();
    P (*thread_attach)(P);
};
bool finite(Vec3 v) { return std::isfinite(v.x)&&std::isfinite(v.y)&&std::isfinite(v.z); }
NSArray* array(Vec3 v) { return @[@(v.x),@(v.y),@(v.z)]; }
constexpr uint8_t expectedUUID[16]={0xc8,0xde,0x73,0x71,0xcb,0xa7,0x3e,0x7a,0x9e,0x09,0x30,0xb8,0xe1,0xb8,0x90,0x73};
}

@implementation ZucchiniRuntime {
    API api;
    bool ready;
    bool fault;
    NSString *_status;
    NSUInteger _reads, _writes;
    P playerClass, facadeClass, objectClass, transformClass, physicsClass, hitClass, quatClass;
    P localMethod, matchMethod, teammateMethod, deadMethod, dyingMethod, visibleMethod;
    P headMethod, neckMethod, positionMethod, forwardMethod, rootMethod, childMethod;
    P raycastMethod, hitTransformMethod, lookMethod, setAimMethod, findMethod, instanceMethod;
    P cameraField;
    int hitSize;
    uint32_t matchHandle, localHandle;
    std::vector<uint32_t> players;
    std::map<std::string,uint32_t> lastTargets;
    std::map<std::string,P> methods;
    double refreshedAt, capturedAt;
    uint64_t sequence, epoch;
    NSString *selectedPoint;
}
- (instancetype)init {
    if ((self=[super init])) { _status=@"Waiting for game"; }
    return self;
}
- (NSString*)status { return _status; }
- (NSUInteger)reads { return _reads; }
- (NSUInteger)writes { return _writes; }
- (P)findClass:(const char*)name space:(const char*)space image:(const char*)imageName {
    size_t count=0; const P* assemblies=api.domain_get_assemblies(api.domain_get(),&count);
    if (!assemblies || count>1024) return nullptr;
    for (size_t i=0;i<count;i++) {
        P image=api.assembly_get_image(assemblies[i]);
        const char *nameInImage=image?api.image_get_name(image):nullptr;
        if (nameInImage && strcmp(nameInImage,imageName)==0) return api.class_from_name(image,space,name);
    }
    return nullptr;
}
- (P)method:(const char*)name on:(P)klass count:(uint32_t)count firstType:(const char*)firstType {
    if (!klass) return nullptr;
    std::string key=std::to_string((uintptr_t)klass)+":"+name+":"+std::to_string(count)+":"+(firstType?firstType:"");
    auto cached=methods.find(key); if (cached!=methods.end()) return cached->second;
    for (P c=klass;c;c=api.class_get_parent(c)) {
        P iterator=nullptr;
        while (P m=api.class_get_methods(c,&iterator)) {
            if (strcmp(api.method_get_name(m),name)!=0 || api.method_get_param_count(m)!=count) continue;
            if (firstType && count) {
                char* actual=api.type_get_name(api.method_get_param(m,0));
                bool match=actual && strcmp(actual,firstType)==0; if (actual) api.free(actual);
                if (!match) continue;
            }
            methods[key]=m; return m;
        }
    }
    return nullptr;
}
- (P)call:(P)method object:(P)object arguments:(P*)arguments {
    if (!method) { fault=true; _status=@"Required method missing"; return nullptr; }
    P exception=nullptr;
    P result=api.runtime_invoke(method,object,arguments,&exception);
    if (exception) { fault=true; _status=[NSString stringWithFormat:@"Game rejected call: %s",api.method_get_name(method)]; return nullptr; }
    return result;
}
- (BOOL)boolean:(P)method object:(P)object arguments:(P*)arguments fallback:(BOOL)fallback {
    P box=[self call:method object:object arguments:arguments];
    if (fault || !box) { fault=true; return fallback; }
    return *static_cast<bool*>(api.object_unbox(box));
}
- (BOOL)position:(P)transform into:(Vec3*)out method:(P)method {
    if (!transform) return NO;
    P box=[self call:method object:transform arguments:nullptr];
    if (!box || fault) return NO;
    memcpy(out,api.object_unbox(box),sizeof(Vec3)); return finite(*out);
}
- (BOOL)initializeRuntime {
    if (ready) return YES;
    if (![[NSBundle mainBundle].bundleIdentifier isEqualToString:@"com.dts.freefireth"] ||
        ![[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] isEqualToString:@"1.132.1"]) {
        _status=@"Unsupported game version"; return NO;
    }
    const char *path=nullptr;
    for (uint32_t i=0;i<_dyld_image_count();i++) {
        const char *name=_dyld_get_image_name(i);
        if (!name || !strstr(name,"/UnityFramework.framework/UnityFramework")) continue;
        const mach_header_64 *h=(const mach_header_64*)_dyld_get_image_header(i);
        if (h->magic!=MH_MAGIC_64) continue;
        const uint8_t *p=(const uint8_t*)(h+1);
        for (uint32_t j=0;j<h->ncmds;j++) {
            const load_command *lc=(const load_command*)p;
            if (lc->cmd==LC_UUID && memcmp(((const uuid_command*)lc)->uuid,expectedUUID,16)==0) path=name;
            p+=lc->cmdsize;
        }
    }
    if (!path) { _status=@"Waiting for matching Unity build"; return NO; }
    P library=dlopen(path,RTLD_NOW|RTLD_NOLOAD);
    if (!library) { _status=@"Unity image unavailable"; return NO; }
    bool loaded=true;
#define LOAD(name) api.name=reinterpret_cast<decltype(api.name)>(dlsym(library,"il2cpp_" #name)); loaded=loaded&&api.name;
    LOAD(domain_get) LOAD(domain_get_assemblies) LOAD(assembly_get_image) LOAD(image_get_name)
    LOAD(class_from_name) LOAD(class_get_parent) LOAD(class_get_methods) LOAD(method_get_name)
    LOAD(method_get_param_count) LOAD(method_get_param) LOAD(type_get_name) LOAD(free)
    LOAD(class_get_type) LOAD(type_get_object) LOAD(object_get_class) LOAD(object_unbox)
    LOAD(runtime_invoke) LOAD(array_length) LOAD(class_get_field_from_name) LOAD(field_get_value)
    LOAD(class_value_size) LOAD(gchandle_new) LOAD(gchandle_get_target) LOAD(gchandle_free)
    LOAD(thread_current) LOAD(thread_attach)
#undef LOAD
    dlclose(library);
    if (!loaded || !api.domain_get()) { _status=@"Runtime not ready"; return NO; }
    if (!api.thread_current()) api.thread_attach(api.domain_get());
    facadeClass=[self findClass:"GameFacade" space:"COW" image:"Assembly-CSharp.dll"];
    playerClass=[self findClass:"Player" space:"COW.GamePlay" image:"Assembly-CSharp.dll"];
    objectClass=[self findClass:"Object" space:"UnityEngine" image:"UnityEngine.CoreModule.dll"];
    transformClass=[self findClass:"Transform" space:"UnityEngine" image:"UnityEngine.CoreModule.dll"];
    physicsClass=[self findClass:"Physics" space:"UnityEngine" image:"UnityEngine.PhysicsModule.dll"];
    hitClass=[self findClass:"RaycastHit" space:"UnityEngine" image:"UnityEngine.PhysicsModule.dll"];
    quatClass=[self findClass:"Quaternion" space:"UnityEngine" image:"UnityEngine.CoreModule.dll"];
    if (!facadeClass || !playerClass || !objectClass || !transformClass || !physicsClass || !hitClass || !quatClass) {
        _status=@"Required game types unavailable"; return NO;
    }
#define METHOD(variable,name,cls,n,type) variable=[self method:name on:cls count:n firstType:type]; if (!variable) { _status=[NSString stringWithFormat:@"Missing method: %s",name]; return NO; }
    METHOD(localMethod,"CurrentLocalPlayer",facadeClass,0,nullptr)
    METHOD(matchMethod,"CurrentMatch",facadeClass,0,nullptr)
    METHOD(teammateMethod,"IsLocalTeammate",facadeClass,1,"COW.GamePlay.Player")
    METHOD(deadMethod,"get_IsDead",playerClass,0,nullptr)
    METHOD(dyingMethod,"get_IsDieing",playerClass,0,nullptr)
    METHOD(visibleMethod,"IsVisible",playerClass,0,nullptr)
    METHOD(headMethod,"get_HeadBoneTransform",playerClass,0,nullptr)
    METHOD(neckMethod,"get_NeckBone",playerClass,0,nullptr)
    METHOD(rootMethod,"get_transform",playerClass,0,nullptr)
    METHOD(positionMethod,"get_position",transformClass,0,nullptr)
    METHOD(forwardMethod,"get_forward",transformClass,0,nullptr)
    METHOD(childMethod,"IsChildOf",transformClass,1,"UnityEngine.Transform")
    METHOD(raycastMethod,"Raycast",physicsClass,6,"UnityEngine.Vector3")
    METHOD(hitTransformMethod,"get_transform",hitClass,0,nullptr)
    METHOD(lookMethod,"LookRotation",quatClass,2,"UnityEngine.Vector3")
    METHOD(setAimMethod,"SetAimRotation",playerClass,2,"UnityEngine.Quaternion")
    METHOD(findMethod,"FindObjectsOfType",objectClass,1,"System.Type")
    METHOD(instanceMethod,"GetInstanceID",objectClass,0,nullptr)
#undef METHOD
    cameraField=api.class_get_field_from_name(playerClass,"MainCameraTransform");
    uint32_t alignment=0; hitSize=api.class_value_size(hitClass,&alignment);
    if (!cameraField || hitSize<16 || hitSize>512) { _status=@"Invalid runtime layout"; return NO; }
    ready=true; _status=@"Game methods resolved"; return YES;
}
- (void)reset {
    if (api.gchandle_free) {
        for (auto handle:players) api.gchandle_free(handle);
        if (localHandle) api.gchandle_free(localHandle);
        if (matchHandle) api.gchandle_free(matchHandle);
    }
    players.clear(); lastTargets.clear(); localHandle=matchHandle=0; refreshedAt=0; epoch++;
}
- (BOOL)eligible:(P)player local:(P)local {
    if (!player || player==local) return NO;
    P args[]={player};
    if ([self boolean:teammateMethod object:nullptr arguments:args fallback:YES]) return NO;
    if ([self boolean:deadMethod object:player arguments:nullptr fallback:YES]) return NO;
    if ([self boolean:dyingMethod object:player arguments:nullptr fallback:YES]) return NO;
    return [self boolean:visibleMethod object:player arguments:nullptr fallback:NO] && !fault;
}
- (BOOL)lineOfSightFrom:(Vec3)origin to:(Vec3)target player:(P)player {
    std::vector<uint64_t> hit((hitSize+7)/8,0);
    int mask=-1; int ignoreTriggers=1;
    Vec3 direction={target.x-origin.x,target.y-origin.y,target.z-origin.z};
    float distance=sqrtf(direction.x*direction.x+direction.y*direction.y+direction.z*direction.z);
    if (!std::isfinite(distance) || distance<1e-6f) return NO;
    direction={direction.x/distance,direction.y/distance,direction.z/distance};
    P args[]={&origin,&direction,hit.data(),&distance,&mask,&ignoreTriggers};
    BOOL collided=[self boolean:raycastMethod object:nullptr arguments:args fallback:YES];
    if (fault) return NO;
    if (!collided) return YES;
    P transform=[self call:hitTransformMethod object:hit.data() arguments:nullptr];
    P root=[self call:rootMethod object:player arguments:nullptr];
    if (!transform || !root || fault) return NO;
    P childArgs[]={root};
    return [self boolean:childMethod object:transform arguments:childArgs fallback:NO] && !fault;
}
- (NSDictionary*)captureTarget:(NSString*)target fov:(double)fov {
    NSAssert([NSThread isMainThread],@"Runtime capture must use main thread");
    _reads++; fault=false; lastTargets.clear();
    if (![self initializeRuntime] || !std::isfinite(fov) || fov<1 || fov>180) return nil;
    P local=[self call:localMethod object:nullptr arguments:nullptr];
    P match=[self call:matchMethod object:nullptr arguments:nullptr];
    if (!local || !match || fault) { [self reset]; _status=@"Waiting for playable match"; return nil; }
    if (!matchHandle || !localHandle || match!=api.gchandle_get_target(matchHandle) || local!=api.gchandle_get_target(localHandle)) {
        [self reset]; matchHandle=api.gchandle_new(match,false); localHandle=api.gchandle_new(local,false);
    }
    if ([self boolean:deadMethod object:local arguments:nullptr fallback:YES] ||
        [self boolean:dyingMethod object:local arguments:nullptr fallback:YES] || fault) {
        [self reset]; _status=@"Local player inactive"; return nil;
    }
    P camera=nullptr; api.field_get_value(local,cameraField,&camera);
    Vec3 origin,forward;
    if (![self position:camera into:&origin method:positionMethod] || ![self position:camera into:&forward method:forwardMethod]) {
        _status=@"Camera unavailable"; return nil;
    }
    double now=CACurrentMediaTime();
    if (now-refreshedAt>0.5 || refreshedAt==0) {
        for (auto handle:players) api.gchandle_free(handle); players.clear();
        P type=api.type_get_object(api.class_get_type(playerClass)); P args[]={type};
        P objects=type?[self call:findMethod object:nullptr arguments:args]:nullptr;
        if (!objects || fault) { _status=@"Player enumeration unavailable"; return nil; }
        uintptr_t count=api.array_length(objects);
        if (count>1024) { _status=@"Player count outside limits"; return nil; }
        uint32_t arrayHandle=api.gchandle_new(objects,false);
        P getter=[self method:"GetValue" on:api.object_get_class(objects) count:1 firstType:"System.Int32"];
        for (int32_t i=0;i<(int32_t)count;i++) {
            P a[]={&i}; P player=[self call:getter object:objects arguments:a];
            if (fault) break;
            if (player && player!=local) players.push_back(api.gchandle_new(player,false));
        }
        api.gchandle_free(arrayHandle);
        refreshedAt=now;
    }
    if (fault) return nil;
    struct Candidate { uint32_t handle; P player; Vec3 head,neck; bool hasHead,hasNeck; double angle; int32_t id; };
    std::vector<Candidate> candidates;
    bool headTarget=[target isEqualToString:@"Head"];
    if (!headTarget && ![target isEqualToString:@"Neck"]) return nil;
    for (auto handle:players) {
        P player=api.gchandle_get_target(handle);
        if (![self eligible:player local:local]) { if(fault) break; else continue; }
        Candidate candidate{}; candidate.handle=handle; candidate.player=player;
        P head=[self call:headMethod object:player arguments:nullptr];
        P neck=[self call:neckMethod object:player arguments:nullptr];
        candidate.hasHead=[self position:head into:&candidate.head method:positionMethod];
        candidate.hasNeck=[self position:neck into:&candidate.neck method:positionMethod];
        if (fault) break;
        if (headTarget?!candidate.hasHead:!candidate.hasNeck) continue;
        Vec3 point=headTarget?candidate.head:candidate.neck;
        double dx=point.x-origin.x,dy=point.y-origin.y,dz=point.z-origin.z;
        double length=sqrt(dx*dx+dy*dy+dz*dz),fl=sqrt(forward.x*forward.x+forward.y*forward.y+forward.z*forward.z);
        if (!(length>1e-6 && fl>1e-6)) continue;
        candidate.angle=acos(std::clamp((dx*forward.x+dy*forward.y+dz*forward.z)/(length*fl),-1.0,1.0));
        if (candidate.angle>fov*M_PI/360) continue;
        P id=[self call:instanceMethod object:player arguments:nullptr]; if (!id || fault) break;
        memcpy(&candidate.id,api.object_unbox(id),sizeof(int32_t));
        candidates.push_back(candidate);
    }
    if (fault) return nil;
    std::sort(candidates.begin(),candidates.end(),[](const Candidate&a,const Candidate&b){return a.angle<b.angle;});
    NSMutableArray *output=[NSMutableArray array];
    // Bound physics work. Conservative exclusion if the nearest eight are occluded.
    for (size_t i=0;i<std::min<size_t>(8,candidates.size());i++) {
        const auto &c=candidates[i]; Vec3 point=headTarget?c.head:c.neck;
        if (![self lineOfSightFrom:origin to:point player:c.player]) { if(fault) break; else continue; }
        NSString *identifier=[NSString stringWithFormat:@"%llu:%d",(unsigned long long)epoch,c.id];
        lastTargets[identifier.UTF8String]=c.handle;
        NSMutableDictionary *item=[@{@"id":identifier} mutableCopy];
        if (c.hasHead) item[@"head"]=array(c.head);
        if (c.hasNeck) item[@"neck"]=array(c.neck);
        [output addObject:item];
    }
    if (fault) {lastTargets.clear(); return nil;}
    selectedPoint=[target copy]; sequence++; capturedAt=CACurrentMediaTime();
    _status=output.count?@"Targets available":@"No eligible visible target";
    return @{@"sequence":@(sequence),@"capturedAt":@(capturedAt),@"origin":array(origin),@"forward":array(forward),@"targets":output};
}
- (BOOL)applyX:(double)x y:(double)y z:(double)z targetID:(NSString*)targetID sequence:(uint64_t)frameSequence {
    if (!ready || fault || frameSequence!=sequence || CACurrentMediaTime()-capturedAt>0.1 ||
        !std::isfinite(x)||!std::isfinite(y)||!std::isfinite(z)) return NO;
    auto found=lastTargets.find(targetID.UTF8String); if(found==lastTargets.end()) return NO;
    P target=api.gchandle_get_target(found->second),local=api.gchandle_get_target(localHandle),match=api.gchandle_get_target(matchHandle);
    if (!local || !match || [self call:localMethod object:nullptr arguments:nullptr]!=local ||
        [self call:matchMethod object:nullptr arguments:nullptr]!=match || ![self eligible:target local:local]) return NO;
    if ([self boolean:deadMethod object:local arguments:nullptr fallback:YES] || fault) return NO;
    double length=sqrt(x*x+y*y+z*z); if (!std::isfinite(length)||length<1e-8) return NO;
    Vec3 direction={(float)(x/length),(float)(y/length),(float)(z/length)}, up={0,1,0};
    P args[]={&direction,&up}; P boxed=[self call:lookMethod object:nullptr arguments:args];
    if (!boxed || fault) return NO;
    Quaternion rotation; memcpy(&rotation,api.object_unbox(boxed),sizeof(rotation));
    bool apply=true; P aimArgs[]={&rotation,&apply};
    [self call:setAimMethod object:local arguments:aimArgs];
    if (fault) return NO;
    _writes++; _status=@"Aim command applied"; lastTargets.clear(); return YES;
}
@end

extern "C" void zucchiniStart(void);
__attribute__((constructor)) static void startZucchini() {
    dispatch_async(dispatch_get_main_queue(), ^{ zucchiniStart(); });
}
