#include <math.h>
#include <stdlib.h>
#include <limits.h>
#include <stdio.h>

#define PI (4*atan2(1,1))

unsigned int simChannelResponse(unsigned int in, unsigned char i)
{
   unsigned int out_r;
   unsigned int out_i;
   static double scaling = 1;  // constant scaling factor
   static double rotation = 0;   // can at most rotate 1/64 circle between subcarrier
   double rel, img;
   double rot_rel, rot_img;
   double out_rel, out_img;
   if (i == 0) // only reset for new packet
   {
      scaling = (rand()/((double)RAND_MAX + 1))*2;
      rotation = (rand()/((double)RAND_MAX + 1))/32; // at most rotation half a circle between two pilots
   }
   rel = (double) ((short) (in % (1<<16)));   // extract rel (i)
   img = (double) ((short) (in >> 16));      // extract img (q)
   rel *= scaling;  // constant scaling
   img *= scaling;  // constant scaling
   rot_rel = cos(2*PI*rotation*i);
   rot_img = sin(2*PI*rotation*i);
   out_rel = rel*rot_rel - img*rot_img;
   out_img = rel*rot_img + img*rot_rel;
   if(out_rel >= 32768)
      out_rel = 32767;
   if(out_rel < -32768)
      out_rel = -32768;
   if(out_img >= 32768)
      out_img = 32767;
   if(out_img < -32768)
      out_img = -32768;
   out_r = (((unsigned int)out_rel)%(1<<16));
   out_i = (((unsigned int)out_img)<<16);
   return out_r+out_i;
}


