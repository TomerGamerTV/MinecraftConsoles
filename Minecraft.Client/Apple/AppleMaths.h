// AppleMaths.h - DirectXMath compatibility for Apple platforms
// Provides XMFLOAT4X4, XMVECTOR, etc. used by the codebase

#pragma once
#include <cmath>
#include <cstring>

// XMFLOAT4X4 - 4x4 matrix
struct XMFLOAT4X4 {
    union {
        struct {
            float _11, _12, _13, _14;
            float _21, _22, _23, _24;
            float _31, _32, _33, _34;
            float _41, _42, _43, _44;
        };
        float m[4][4];
    };
    XMFLOAT4X4() { memset(this, 0, sizeof(*this)); }
    XMFLOAT4X4(float m00, float m01, float m02, float m03,
                float m10, float m11, float m12, float m13,
                float m20, float m21, float m22, float m23,
                float m30, float m31, float m32, float m33) {
        _11=m00; _12=m01; _13=m02; _14=m03;
        _21=m10; _22=m11; _23=m12; _24=m13;
        _31=m20; _32=m21; _33=m22; _34=m23;
        _41=m30; _42=m31; _43=m32; _44=m33;
    }
};

struct XMFLOAT3 {
    float x, y, z;
    XMFLOAT3() : x(0), y(0), z(0) {}
    XMFLOAT3(float x, float y, float z) : x(x), y(y), z(z) {}
};

struct XMFLOAT4 {
    float x, y, z, w;
    XMFLOAT4() : x(0), y(0), z(0), w(0) {}
    XMFLOAT4(float x, float y, float z, float w) : x(x), y(y), z(z), w(w) {}
};

// Minimal XMVECTOR for compatibility (just a float4)
typedef XMFLOAT4 XMVECTOR;

// XMMatrixIdentity
inline XMFLOAT4X4 XMMatrixIdentity() {
    return XMFLOAT4X4(1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1);
}
