struct roi_t
{
  uvec2 full;      // full input size
  uvec2 roi;       // dimensions of region of interest
  ivec2 off;       // offset in full image
  float scale;     // wd * scale is on input scale
  float pad0;      // alignment of structs will be a multiple of vec4 it seems :(
  // so we pad explicitly for sanity of mind.
  // alternatively we could specify layout(offset=48) etc below.
};

// http://vec3.ca/bicubic-filtering-in-fewer-taps/
vec4 sample_catmull_rom(sampler2D tex, vec2 uv)
{
  // We're going to sample a a 4x4 grid of texels surrounding the target UV coordinate. We'll do this by rounding
  // down the sample location to get the exact center of our "starting" texel. The starting texel will be at
  // location [1, 1] in the grid, where [0, 0] is the top left corner.
  vec2 texSize = textureSize(tex, 0);
  vec2 samplePos = uv * texSize;
  vec2 texPos1 = floor(samplePos - 0.5) + 0.5;

  // Compute the fractional offset from our starting texel to our original sample location, which we'll
  // feed into the Catmull-Rom spline function to get our filter weights.
  vec2 f = samplePos - texPos1;

  // Compute the Catmull-Rom weights using the fractional offset that we calculated earlier.
  // These equations are pre-expanded based on our knowledge of where the texels will be located,
  // which lets us avoid having to evaluate a piece-wise function.
  vec2 w0 = f * ( -0.5 + f * (1.0 - 0.5*f));
  vec2 w1 = 1.0 + f * f * (-2.5 + 1.5*f);
  vec2 w2 = f * ( 0.5 + f * (2.0 - 1.5*f) );
  vec2 w3 = f * f * (-0.5 + 0.5 * f);

  // Work out weighting factors and sampling offsets that will let us use bilinear filtering to
  // simultaneously evaluate the middle 2 samples from the 4x4 grid.
  vec2 w12 = w1 + w2;
  vec2 offset12 = w2 / (w1 + w2);

  // Compute the final UV coordinates we'll use for sampling the texture
  vec2 texPos0 = texPos1 - vec2(1.0);
  vec2 texPos3 = texPos1 + vec2(2.0);
  vec2 texPos12 = texPos1 + offset12;

  texPos0 /= texSize;
  texPos3 /= texSize;
  texPos12 /= texSize;

  vec4 result = vec4(0.0);
  result += textureLod(tex, vec2(texPos0.x,  texPos0.y),  0) * w0.x * w0.y;
  result += textureLod(tex, vec2(texPos12.x, texPos0.y),  0) * w12.x * w0.y;
  result += textureLod(tex, vec2(texPos3.x,  texPos0.y),  0) * w3.x * w0.y;

  result += textureLod(tex, vec2(texPos0.x,  texPos12.y), 0) * w0.x * w12.y;
  result += textureLod(tex, vec2(texPos12.x, texPos12.y), 0) * w12.x * w12.y;
  result += textureLod(tex, vec2(texPos3.x,  texPos12.y), 0) * w3.x * w12.y;

  result += textureLod(tex, vec2(texPos0.x,  texPos3.y),  0) * w0.x * w3.y;
  result += textureLod(tex, vec2(texPos12.x, texPos3.y),  0) * w12.x * w3.y;
  result += textureLod(tex, vec2(texPos3.x,  texPos3.y),  0) * w3.x * w3.y;

  return result;
}

float luminance_rec2020(vec3 rec2020)
{
  // excerpt from the rec2020 to xyz matrix (y channel only)
  vec3 w = vec3(0.2126729, 0.7151522, 0.0721750);
  return dot(w, rec2020);
}
