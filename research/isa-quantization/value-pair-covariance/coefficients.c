#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <inttypes.h>

enum { ROWS=1024, COLS=2048, LAYERS=2, KV_HEADS=8, GROUPS=4, WIDTH=32 };
static int64_t o[LAYERS][ROWS][COLS];

static void load(int layer, const char *path) {
    FILE *f=fopen(path,"rb");
    if (!f) { perror(path); exit(1); }
    for (int row=0;row<ROWS;row++) for (int col=0;col<COLS;col++) {
        unsigned char b[2];
        if (fread(b,1,2,f)!=2) { fprintf(stderr,"short BF16 input: %s\n",path); exit(1); }
        uint16_t x=(uint16_t)b[0]|((uint16_t)b[1]<<8);
        int exp=(x>>7)&255;
        if (exp==0 && (x&127)==0) continue;
        if (exp<99 || exp>125) { fprintf(stderr,"BF16 exponent outside certified bound: %s, %d\n",path,exp); exit(1); }
        int64_t v=(int64_t)(128+(x&127))<<(exp-99);
        o[layer][row][col]=(x&0x8000)?-v:v;
    }
    if (fgetc(f)!=EOF) { fprintf(stderr,"long BF16 input: %s\n",path); exit(1); }
    if (ferror(f) || fclose(f)) { perror(path); exit(1); }
}
static void print128(__int128 v) {
    if(v<0){putchar('-');v=-v;}
    char b[40];int n=0;
    do { b[n++]='0'+v%10;v/=10; } while(v);
    while(n)putchar(b[--n]);
}
int main(int argc,char **argv){
    if(argc!=3){fprintf(stderr,"usage: coefficients O0.bf16 O1.bf16 > coefficients.tsv\n");return 2;}
    load(0,argv[1]);load(1,argv[2]);
    puts("layer\thead\tgroup\ti\tj\tA\tB\tD");
    for(int layer=0;layer<LAYERS;layer++)for(int h=0;h<KV_HEADS;h++)for(int g=0;g<GROUPS;g++)for(int a=0;a<WIDTH;a++)for(int b=a+1;b<WIDTH;b++){
        int i=h*128+g*32+a,j=h*128+g*32+b;
        int q0i=(2*h)*128+g*32+a,q0j=(2*h)*128+g*32+b;
        int q1i=(2*h+1)*128+g*32+a,q1j=(2*h+1)*128+g*32+b;
        __int128 A=0,B=0,D=0;
        for(int k=0;k<ROWS;k++){
            A+=(__int128)o[layer][k][q0i]*o[layer][k][q0j];
            D+=(__int128)o[layer][k][q1i]*o[layer][k][q1j];
            B+=(__int128)o[layer][k][q0i]*o[layer][k][q1j]+(__int128)o[layer][k][q1i]*o[layer][k][q0j];
        }
        printf("%d\t%d\t%d\t%d\t%d\t",layer,h,g,i,j);print128(A);putchar('\t');print128(B);putchar('\t');print128(D);putchar('\n');
    }
    return 0;
}
