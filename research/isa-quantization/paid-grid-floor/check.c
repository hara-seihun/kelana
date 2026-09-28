#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <inttypes.h>
#define N 128
#define KEEP 64
#define K 16
#define INF (INT64_MAX/4)
static int64_t f[K+1][KEEP+1][N+1], a[N], score[N+1][N+1];
static int order(const void *u,const void *v) {
    int64_t x=*(const int64_t *)u,y=*(const int64_t *)v;
    return (x>y)-(x<y);
}
int main(void) {
    for (int row=0;row<N;row++) {
        for (int j=0;j<N;j++) if (scanf("%" SCNd64,&a[j])!=1) return 2;
        qsort(a,N,sizeof(*a),order);
        for (int left=0;left<N;left++) {
            int64_t sum=0,squares=0;
            for (int right=left+1;right<=N;right++) {
                int64_t x=a[right-1],len=right-left;
                sum+=x;squares+=x*x;
                int64_t numerator=len*squares-sum*sum;
                if (numerator<0) return 3;
                score[left][right]=numerator/len;
            }
        }
        for (int k=0;k<=K;k++) for (int q=0;q<=KEEP;q++)
            for (int j=0;j<=N;j++) f[k][q][j]=INF;
        f[0][0][0]=0;
        for (int j=0;j<=N;j++) for (int k=0;k<=K;k++) for (int q=0;q<=KEEP;q++) {
            int64_t value=f[k][q][j];
            if (value==INF) continue;
            if (j<N && value<f[k][q][j+1]) f[k][q][j+1]=value;
            if (k==K) continue;
            for (int end=j+1;end<=N && q+end-j<=KEEP;end++) {
                int64_t next=value+score[j][end];
                if (next<f[k+1][q+end-j][end]) f[k+1][q+end-j][end]=next;
            }
        }
        int64_t best=INF;
        for (int k=1;k<=K;k++) if (f[k][KEEP][N]<best) best=f[k][KEEP][N];
        if (best==INF) return 4;
        printf("%" PRId64 "\n",best);
    }
    if (scanf("%" SCNd64,&a[0])==1) return 5;
    return 0;
}
