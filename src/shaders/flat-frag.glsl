#version 300 es
precision highp float;

uniform vec3 u_Eye, u_Ref, u_Up;
uniform vec2 u_Dimensions;
uniform float u_Time;
uniform float u_Speed;
uniform float u_Space;

in vec2 fs_Pos;
out vec4 out_Col;

float bias(float b, float t) {
  return pow(t, log(b) / log(0.5f));
}

float gain(float g, float t) {
  if(t < 0.5f) {
    return bias(1.f-g, 2.f*t) / 2.f;
  } else {
    return 1.f - bias(1.f-g, 2.f - 2.f * t) / 2.f;
  }
}

vec2 random2( vec2 p , vec2 seed) {
  return fract(sin(vec2(dot(p + seed, vec2(311.7, 127.1)), dot(p + seed, vec2(269.5, 183.3)))) * 85734.3545);
}

float falloff(float t) {
  return t*t*t*(t*(t*6.f - 15.f) + 10.f);;
}

float lerp(float a, float b, float t) {
  return (1.0 - t) * a + t * b;
}

//ix and iy are the corner coordinates
float dotGridGradient(int ix, int iy, float x, float y, float seed) {
  vec2 dist = vec2(x - float(ix), y - float(iy));
  vec2 rand = (random2(vec2(ix, iy), vec2(seed, seed * 2.139)) * 2.f) - 1.f;
  return dist[0] * rand[0] + dist[1] * rand[1];
}

//Perlin returns a value in [-1, 1]
float perlin(vec2 pos, float seed) {
  //Pixel lies in (x0, y0)
  int x0 = int(floor(pos[0]));
  int x1 = x0 + 1;
  int y0 = int(floor(pos[1]));
  int y1 = y0 + 1;

  float wx = falloff(pos[0] - float(x0));
  float wy = falloff(pos[1] - float(y0));

  float n0, n1, ix0, ix1, value;
  n0 = dotGridGradient(x0, y0, pos[0], pos[1], seed);
  n1 = dotGridGradient(x1, y0, pos[0], pos[1], seed);
  ix0 = lerp(n0, n1, wx);
  n0 = dotGridGradient(x0, y1, pos[0], pos[1], seed);
  n1 = dotGridGradient(x1, y1, pos[0], pos[1], seed);
  ix1 = lerp(n0, n1, wx);
  value = lerp(ix0, ix1, wy);

  return value;
}

vec3 palette(float t, vec3 a, vec3 b, vec3 c, vec3 d ) {
    return a + b*cos( 6.28318*(c*t+d) );
}

mat4 translate(vec3 t) {
  mat4 m = mat4(1);
  m[3] = vec4(t, 1);
  return m;
}

mat4 rotate(vec3 r) {
  r = radians(r);
  mat4 x = mat4(1, 0, 0, 0, 
                0, cos(r[0]), sin(r[0]), 0,
                0, -sin(r[0]), cos(r[0]), 0,
                0, 0, 0, 1);
  mat4 y = mat4(cos(r[1]), 0, -sin(r[1]), 0,
                0, 1, 0, 0,
                sin(r[1]), 0, cos(r[1]), 0,
                0, 0, 0, 1);
  mat4 z = mat4(cos(r[2]), sin(r[2]), 0, 0,
                -sin(r[2]), cos(r[2]), 0, 0,
                0, 0, 1, 0,
                0, 0, 0, 1);
  return x * y * z;
}

float sdSphere(vec3 p, float r) {
  return length(p) - r;
}

float sdBox(vec3 p, vec3 b) {
  vec3 d = abs(p) - b;
  return length(max(d, 0.0)) + min(max(d.x, max(d.y, d.z)), 0.0);
}

float sdTorus(vec3 p, vec2 t) {
  vec2 q = vec2(length(p.xz) - t.x, p.y);
  return length(q) - t.y;
}

float sdHexPrism(vec3 p, vec2 h) {
  const vec3 k = vec3(-0.8660254, 0.5, 0.57735);
  p = abs(p);
  p.xy -= 2.0*min(dot(k.xy, p.xy), 0.0)*k.xy;
  vec2 d = vec2(
      length(p.xy-vec2(clamp(p.x,-k.z*h.x,k.z*h.x), h.x))*sign(p.y-h.x),
      p.z-h.y );
  return min(max(d.x,d.y),0.0) + length(max(d,0.0));
}

float opSmoothSubtraction( float d1, float d2, float k ) {
    float h = clamp( 0.5 - 0.5*(d2+d1)/k, 0.0, 1.0 );
    return mix( d2, -d1, h ) + k*h*(1.0-h);
}

float opSmoothIntersection( float d1, float d2, float k ) {
    float h = clamp( 0.5 - 0.5*(d2-d1)/k, 0.0, 1.0 );
    return mix( d2, d1, h ) + k*h*(1.0-h);
}

vec3 opRep(vec3 p, vec3 c) {
    vec3 q = mod(p,c)-0.5*c;
    return q;
}

float getScale(int id) {
  //insert ids here if using scale
  if(id == 0) {
    return 1.f;
  }
  return 1.f;
}

mat4 getTransform(int id) {
  float slow = 360.f * fract(u_Time * u_Speed / 500.f);
  float med = 360.f * fract(u_Time * u_Speed / 100.f);
  float fast = 360.f * fract(u_Time * u_Speed / 30.f);
  if(id == 0) {
    //slow sphere
    float dist = mod(u_Time * 360.f / 10000.f, u_Space);
    dist = dist / u_Space;
    dist = gain(0.8, dist);
    dist = dist * u_Space;
    return translate(vec3(0, 0, dist));
  } else if(id == 1) {
    //wonky box
    return rotate(vec3(0, slow, med)) * translate(vec3(10, -5, 0)) * rotate(vec3(med, med, 0));
  } else if(id == 2) {
    //centerpiece
    return rotate(vec3(0, fast, 0));
  } else if(id == 3) {
    //hexagonal dude
    return rotate(vec3(0, 0, med)) * translate(vec3(-13, 0, 0));
  } else if(id == 4) {
    //locus
    return translate(vec3(0, sin(u_Time * 360.f / 10000.f) * 3.f, 0));
  }
}

float getSDF(int id, vec3 p) {
  if(id == 0) {
    p = opRep(p, vec3(u_Space));
    return sdSphere(p, 0.5);
  } else if(id == 1) {
    return sdBox(p, vec3(4, 2, 1));
  } else if(id == 2) {
    //Intersection
    float torus = sdTorus(p, vec2(3.5, 1.5));
    float box = sdBox(p, vec3(2.5, 3, 2.5));
    return opSmoothIntersection(torus, box, 0.5);
  } else if(id == 3) {
    //Subtraction
    float sphere = sdSphere(p, 3.f);
    float insideSphere = sdSphere(p, 1.5);
    float hexPrism = sdHexPrism(p, vec2(3.5, 3));
    return min(opSmoothSubtraction(sphere, hexPrism, 1.5), insideSphere);
    return min(max(sphere, -1.f * hexPrism), insideSphere);
  } else if(id == 4) {
    return sdSphere(p, 1.0);
  }
}

vec3 getBoundDimensions(int id) {
  if(id == 0) {
    return vec3(100, 100, 100);
  } else if(id == 1) {
    return vec3(4.5, 2.5, 1.5);
  } else if(id == 2) {
    return vec3(3, 3.5, 3);
  } else if(id == 3) {
    return vec3(5.5, 5.5, 5.5);
  } else if(id == 4) {
    return vec3(1.5, 1.5, 1.5);
  }
}

vec3 getColor(int id, vec3 p) {
  vec3 target;
  if(id == 0) {
    float t = (perlin(vec2(p) / 100.f, 1.f) + 0.5);
    vec3 a = vec3(0.5, 0.5, 0.5);
    vec3 b = vec3(0.5, 0.5, 0.5);
    vec3 c = vec3(1.0, 1.0, 1.0);
    vec3 d = vec3(0.0, 0.33, 0.67);
    return clamp(palette(t, a, b, c, d), 0.f, 1.f);
  } else if(id == 1) {
    target = vec3(20, 10, 107);
  } else if(id == 2) {
    target = vec3(64, 167, 170);
  } else if(id == 3) {
    target = vec3(96, 3, 22);
  } else if(id == 4) {
    target = vec3(240, 255, 114);
  }
  return target / 255.f;
}

vec3 getMinBound(int id) {
  vec3 p = getBoundDimensions(id);
  
  vec3 ooo = vec3(getTransform(id) * vec4(p * vec3(-1, -1, -1), 1));
  vec3 ooi = vec3(getTransform(id) * vec4(p * vec3(-1, -1, 1), 1));
  vec3 oio = vec3(getTransform(id) * vec4(p * vec3(-1, 1, -1), 1));
  vec3 oii = vec3(getTransform(id) * vec4(p * vec3(-1, 1, 1), 1));
  vec3 ioo = vec3(getTransform(id) * vec4(p * vec3(1, -1, -1), 1));
  vec3 ioi = vec3(getTransform(id) * vec4(p * vec3(1, -1, 1), 1));
  vec3 iio = vec3(getTransform(id) * vec4(p * vec3(1, 1, -1), 1));
  vec3 iii = vec3(getTransform(id) * vec4(p * vec3(1, 1, 1), 1));

  vec3 target;
  for(int i = 0; i < 3; i++) {
    float minI = min(min(min(ooo[i], ooi[i]), min(oio[i], oii[i])), 
                      min(min(ioo[i], ioi[i]), min(iio[i], iii[i])));
    target[i] = minI;
  }
  return target;
}

vec3 getMaxBound(int id) {
  vec3 p = getBoundDimensions(id);
  
  vec3 ooo = vec3(getTransform(id) * vec4(p * vec3(-1, -1, -1), 1));
  vec3 ooi = vec3(getTransform(id) * vec4(p * vec3(-1, -1, 1), 1));
  vec3 oio = vec3(getTransform(id) * vec4(p * vec3(-1, 1, -1), 1));
  vec3 oii = vec3(getTransform(id) * vec4(p * vec3(-1, 1, 1), 1));
  vec3 ioo = vec3(getTransform(id) * vec4(p * vec3(1, -1, -1), 1));
  vec3 ioi = vec3(getTransform(id) * vec4(p * vec3(1, -1, 1), 1));
  vec3 iio = vec3(getTransform(id) * vec4(p * vec3(1, 1, -1), 1));
  vec3 iii = vec3(getTransform(id) * vec4(p * vec3(1, 1, 1), 1));

  vec3 target;
  for(int i = 0; i < 3; i++) {
    float maxI = max(max(max(ooo[i], ooi[i]), max(oio[i], oii[i])), 
                      max(max(ioo[i], ioi[i]), max(iio[i], iii[i])));
    target[i] = maxI;
  }
  return target;
}

//Returns range of t [min, max] in bounding box, -1000 if doesn't hit
vec2 testObjBox(int id, vec3 origin, vec3 dir) {
  vec3 minp = getMinBound(id);
  vec3 maxp = getMaxBound(id);
  float mins[3];
  float maxes[3];
  for(int i = 0; i < 3; ++i) {
    mins[i] = (minp[i] - origin[i]) / dir[i];
    maxes[i] = (maxp[i] - origin[i]) / dir[i];
    if(mins[i] > maxes[i]) {
      float tmp = mins[i];
      mins[i] = maxes[i];
      maxes[i] = tmp;
    }
  }
  float minT = max(mins[0], max(mins[1], mins[2]));
  float maxT = min(maxes[0], min(maxes[1], maxes[2]));
  if(minT > maxT) {
    return vec2(-1000.f, -1000.f);
  }
  return vec2(minT, maxT);
}

vec3 getNormal(int id, vec3 p) {
  float EPSILON = 0.01;
  return normalize(vec3(
      getSDF(id, vec3(p.x + EPSILON, p.y, p.z)) - getSDF(id, vec3(p.x - EPSILON, p.y, p.z)),
      getSDF(id, vec3(p.x, p.y + EPSILON, p.z)) - getSDF(id, vec3(p.x, p.y - EPSILON, p.z)),
      getSDF(id, vec3(p.x, p.y, p.z + EPSILON)) - getSDF(id, vec3(p.x, p.y, p.z - EPSILON))
  ));
}

void main() {
  float fovy = 45.f;
  float aspect = u_Dimensions[0] / u_Dimensions[1];
  float len = length(u_Ref - u_Eye);
  vec3 F = normalize(u_Ref - u_Eye);
  vec3 R = normalize(cross(u_Up, F));
  vec3 V = vec3(u_Up * len * tan(fovy / 2.f));
  vec3 H = vec3(R * len * aspect * tan(fovy / 2.f));
  vec3 world = u_Ref + fs_Pos[0] * H + fs_Pos[1] * V;
  //Calculating ray
  vec3 ray_origin = u_Eye;
  vec3 ray_direction = normalize(world - u_Eye);
  
  //Background
  out_Col = vec4(0.5 * (ray_direction + vec3(1.0, 1.0, 1.0)), 1.0);
  
  //Parameters
  int steps = 300;
  float maxT = 200.f;
  const int numPrimitives = 5;
  //-1000 if ray won't hit object, else holds minT value (bounding box)
  float testObjs[numPrimitives] = float[](-1000.f, -1000.f, -1000.f, -1000.f, -1000.f);

  vec3 curr = ray_origin;
  float t = 0.f;
  float dist;
  //What we want
  int minObject = -1;
  vec3 intersection;
  vec3 normal;

  t = 10000.f;
  for(int id = 0; id < numPrimitives; id++) {
    vec2 minMax = testObjBox(id, ray_origin, ray_direction);
    if(minMax[0] > -900.f) {
      //hits bounding box
      if(minMax[0] < t) {
        //closest bounding box hit
        t = minMax[0];
      }
      testObjs[id] = minMax[0];
    }
  }
  curr = ray_origin + t * ray_direction;

  do {
    dist = 10000.f;
    for(int id = 0; id < numPrimitives; id++) {
      //Check if hits object's bounding box
      if(testObjs[id] > -900.f /*&& id != 0*/) {
        //Test ray with untransformed object
        vec3 temp = vec3(inverse(getTransform(id)) * vec4(curr, 1));
        float currDist = getSDF(id, temp) * getScale(id);
        if(currDist < dist) {
          dist = currDist;
        }
        //Intersects object id
        if(currDist < 0.001) {
          minObject = id;
          intersection = temp;
          normal = normalize(mat3(inverse(transpose(getTransform(id)))) * getNormal(id, intersection));
          intersection = vec3(getTransform(id) * vec4(intersection, 1));
        }
      }
    }
    steps = steps - 1;
    t += dist;
    curr = ray_origin + ray_direction * t;
  } while(dist >= 0.001 && steps > 0 && t < maxT);

  if(minObject > -1) {
    vec3 lightCol = vec3(1, 1, 1);
    vec3 color = getColor(minObject, intersection);
    vec3 lightPos = vec3(translate(vec3(0, sin(u_Time * 360.f / 10000.f) * 3.f, 0)) * vec4(0, 0, 0, 1));
    vec3 toLight = normalize(lightPos - intersection);
    float intensity = dot(toLight, normal);
    //ambient + diffuse
    out_Col = vec4(color * 0.5 + lightCol * color * intensity * 0.5, 1.0);
    if(minObject == 4) {
      out_Col = vec4(1, 1, 1, 1);
    }
  }
}
