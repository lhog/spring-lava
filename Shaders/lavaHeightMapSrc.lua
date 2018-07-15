local fragment = [[
#line 2
//
//  Wombat
//  An efficient texture-free GLSL procedural noise library
//  Source: https://github.com/BrianSharpe/Wombat
//  Derived from: https://github.com/BrianSharpe/GPU-Noise-Lib
//
//  I'm not one for copyrights.  Use the code however you wish.
//  All I ask is that credit be given back to the blog or myself when appropriate.
//  And also to let me know if you come up with any changes, improvements, thoughts or interesting uses for this stuff. :)
//  Thanks!
//
//  Brian Sharpe
//  brisharpe CIRCLE_A yahoo DOT com
//  http://briansharpe.wordpress.com
//  https://github.com/BrianSharpe
//

//
//  This is a modified version of Stefan Gustavson's and Ian McEwan's work at http://github.com/ashima/webgl-noise
//  Modifications are...
//  - faster random number generation
//  - analytical final normalization
//  - space scaled can have an approx feature size of 1.0
//  - filter kernel changed to fix discontinuities at tetrahedron boundaries
//

//
//  Simplex Perlin Noise 3D Deriv
//  Return value range of -1.0->1.0, with format vec4( value, xderiv, yderiv, zderiv )
//
vec4 SimplexPerlin3D_Deriv(vec3 P)
{
    //  https://github.com/BrianSharpe/Wombat/blob/master/SimplexPerlin3D_Deriv.glsl

    //  simplex math constants
    const float SKEWFACTOR = 1.0/3.0;
    const float UNSKEWFACTOR = 1.0/6.0;
    const float SIMPLEX_CORNER_POS = 0.5;
    const float SIMPLEX_TETRAHADRON_HEIGHT = 0.70710678118654752440084436210485;    // sqrt( 0.5 )

    //  establish our grid cell.
    P *= SIMPLEX_TETRAHADRON_HEIGHT;    // scale space so we can have an approx feature size of 1.0
    vec3 Pi = floor( P + dot( P, vec3( SKEWFACTOR) ) );

    //  Find the vectors to the corners of our simplex tetrahedron
    vec3 x0 = P - Pi + dot(Pi, vec3( UNSKEWFACTOR ) );
    vec3 g = step(x0.yzx, x0.xyz);
    vec3 l = 1.0 - g;
    vec3 Pi_1 = min( g.xyz, l.zxy );
    vec3 Pi_2 = max( g.xyz, l.zxy );
    vec3 x1 = x0 - Pi_1 + UNSKEWFACTOR;
    vec3 x2 = x0 - Pi_2 + SKEWFACTOR;
    vec3 x3 = x0 - SIMPLEX_CORNER_POS;

    //  pack them into a parallel-friendly arrangement
    vec4 v1234_x = vec4( x0.x, x1.x, x2.x, x3.x );
    vec4 v1234_y = vec4( x0.y, x1.y, x2.y, x3.y );
    vec4 v1234_z = vec4( x0.z, x1.z, x2.z, x3.z );

    // clamp the domain of our grid cell
    Pi.xyz = Pi.xyz - floor(Pi.xyz * ( 1.0 / 69.0 )) * 69.0;
    vec3 Pi_inc1 = step( Pi, vec3( 69.0 - 1.5 ) ) * ( Pi + 1.0 );

    //	generate the random vectors
    vec4 Pt = vec4( Pi.xy, Pi_inc1.xy ) + vec2( 50.0, 161.0 ).xyxy;
    Pt *= Pt;
    vec4 V1xy_V2xy = mix( Pt.xyxy, Pt.zwzw, vec4( Pi_1.xy, Pi_2.xy ) );
    Pt = vec4( Pt.x, V1xy_V2xy.xz, Pt.z ) * vec4( Pt.y, V1xy_V2xy.yw, Pt.w );
    const vec3 SOMELARGEFLOATS = vec3( 635.298681, 682.357502, 668.926525 );
    const vec3 ZINC = vec3( 48.500388, 65.294118, 63.934599 );
    vec3 lowz_mods = vec3( 1.0 / ( SOMELARGEFLOATS.xyz + Pi.zzz * ZINC.xyz ) );
    vec3 highz_mods = vec3( 1.0 / ( SOMELARGEFLOATS.xyz + Pi_inc1.zzz * ZINC.xyz ) );
    Pi_1 = ( Pi_1.z < 0.5 ) ? lowz_mods : highz_mods;
    Pi_2 = ( Pi_2.z < 0.5 ) ? lowz_mods : highz_mods;
    vec4 hash_0 = fract( Pt * vec4( lowz_mods.x, Pi_1.x, Pi_2.x, highz_mods.x ) ) - 0.49999;
    vec4 hash_1 = fract( Pt * vec4( lowz_mods.y, Pi_1.y, Pi_2.y, highz_mods.y ) ) - 0.49999;
    vec4 hash_2 = fract( Pt * vec4( lowz_mods.z, Pi_1.z, Pi_2.z, highz_mods.z ) ) - 0.49999;

    //	normalize random gradient vectors
    vec4 norm = inversesqrt( hash_0 * hash_0 + hash_1 * hash_1 + hash_2 * hash_2 );
    hash_0 *= norm;
    hash_1 *= norm;
    hash_2 *= norm;

    //	evaluate gradients
    vec4 grad_results = hash_0 * v1234_x + hash_1 * v1234_y + hash_2 * v1234_z;

    //  evaulate the kernel weights ( use (0.5-x*x)^3 instead of (0.6-x*x)^4 to fix discontinuities )
    vec4 m = v1234_x * v1234_x + v1234_y * v1234_y + v1234_z * v1234_z;
    m = max(0.5 - m, 0.0);
    vec4 m2 = m*m;
    vec4 m3 = m*m2;

    //  calc the derivatives
    vec4 temp = -6.0 * m2 * grad_results;
    float xderiv = dot( temp, v1234_x ) + dot( m3, hash_0 );
    float yderiv = dot( temp, v1234_y ) + dot( m3, hash_1 );
    float zderiv = dot( temp, v1234_z ) + dot( m3, hash_2 );

    //	Normalization factor to scale the final result to a strict 1.0->-1.0 range
    //	http://briansharpe.wordpress.com/2012/01/13/simplex-noise/#comment-36
    const float FINAL_NORMALIZATION = 37.837227241611314102871574478976;

    //  sum and return all results as a vec3
    return vec4( dot( m3, grad_results ), xderiv, yderiv, zderiv ) * FINAL_NORMALIZATION;
}

#define FBM_GAIN 0.5
#define FBM_LACUNARITY 1.9

#define noised(x) SimplexPerlin3D_Deriv(x) //noise with analytical derivatives

vec4 fbmd( in vec3 x, int octaves )
{
	float a = 0.0;
	float b = 0.5;
	float f = 1.0;
	vec3  d = vec3(0.0);
	for( int i = 0; i < octaves; i++ )
	{
		vec4 n = noised(f * x);
		a += b * n.x;				// accumulate values
		d += b * n.yzw * f;			// accumulate derivatives
		b *= FBM_GAIN;				// amplitude decrease
		f *= FBM_LACUNARITY;		// frequency increase
	}

	return vec4( a, d );
}

uniform float lavaHeightMapTexX;
uniform float lavaHeightMapTexY;
uniform float time;

#define UVMUL 128.0
#define FBM_OCTAVES 2

void main()
{
	vec2 uv = gl_FragCoord.xy / vec2(lavaHeightMapTexX, lavaHeightMapTexY);

	vec2 uvHM = uv * vec2(UVMUL);
	float timeHM = time * 0.1;

	vec4 pn = fbmd( vec3(uvHM, timeHM), FBM_OCTAVES);

	/// Partial derivatives to normals conversion.
	///	The numerical way:
	///		vec3 va = vec3(dx, dF(x,y)/dx,  0.0);
	///		vec3 vb = vec3(0.0, dF(x,y)/dy, -dy);  //no idea why minus
	///		pn.yzw = normalize( cross(va, vb) );
	/// The analytical way:
	///		vec3 va = vec3(1.0, dF(x,y)/dx,  0.0);
	///		vec3 vb = vec3(0.0, dF(x,y)/dy, -1.0);  //no idea why minus
	///		pn.yzw = normalize( cross(va, vb) );
	/// Shortcut for the analytical way:
	///		pn.yzw = (-dF(x,y)/dx, 1.0, dF(x,y)/dy); because cross product ^^^ is equal to this

	/// abs with preservation of derivatives
	if (pn.x < 0.0)
	{
		pn.xyzw = -pn.xyzw; //flip sign		
	}
	
	vec3 normal = normalize(vec3( -pn.y, 1.0, pn.z ));
	
	///	gl_FragData[0] can't store negatives, so performing the range transition from (-1;1) to (0;1): (x + 1)/2
	//  without abs() above:
	//  vec4 result = vec4(0.5) * (vec4(pn.x, normal.x, normal.y, normal.z) + vec4(1.0));
	//  with abs() above only convert normals:
	vec4 result = vec4(1.0, 0.5, 0.5, 0.5) * (vec4(pn.x, normal.x, normal.y, normal.z) + vec4(0.0, 1.0, 1.0, 1.0));
	//result.x = -123.0;

	gl_FragData[0] = result;
}
]]
return {fragment = fragment}