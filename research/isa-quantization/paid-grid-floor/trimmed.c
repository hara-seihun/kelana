#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <inttypes.h>

#define N 128
#define KEEP 64
#define LEVELS 16
#define INF (INT64_MAX / 4)
static int64_t dp[LEVELS+1][KEEP+1][N+1];
static int64_t cost[N+1][N+1];
static int64_t v[N], s[N+1], ss[N+1];
static int cmp(const void *a, const void *b) {
    int64_t x=*(const int64_t *)a, y=*(const int64_t *)b;
    return (x>y)-(x<y);
}
int main(void) {
    for (int row=0; row<N; ++row) {
        for (int i=0; i<N; ++i) if (scanf("%" SCNd64, &v[i]) != 1) return 2;
        qsort(v,N,sizeof(v[0]),cmp);
        s[0]=ss[0]=0;
        for (int i=0; i<N; ++i) {
            s[i+1]=s[i]+v[i];
            ss[i+1]=ss[i]+v[i]*v[i];
        }
        for (int i=0; i<N; ++i) for (int j=i+1; j<=N; ++j) {
            int64_t len=j-i, sum=s[j]-s[i], squares=ss[j]-ss[i];
            int64_t numerator=len*squares-sum*sum;
            if (numerator<0) return 3;
            cost[i][j]=numerator/len;
        }
        for (int k=0; k<=LEVELS; ++k) for (int q=0; q<=KEEP; ++q)
            for (int j=0; j<=N; ++j) dp[k][q][j]=INF;
        for (int j=0; j<=N; ++j) dp[0][0][j]=0;
        for (int k=1; k<=LEVELS; ++k) {
            for (int j=0; j<=N; ++j) dp[k][0][j]=0;
            for (int j=1; j<=N; ++j) {
                for (int q=1; q<=KEEP && q<=j; ++q) {
                    int64_t best=dp[k][q][j-1];
                    for (int len=1; len<=q && len<=j; ++len) {
                        int64_t previous=dp[k-1][q-len][j-len];
                        if (previous<INF && previous+cost[j-len][j]<best)
                            best=previous+cost[j-len][j];
                    }
                    dp[k][q][j]=best;
                }
            }
        }
        if (dp[LEVELS][KEEP][N]==INF) return 4;
        printf("%" PRId64 "\n",dp[LEVELS][KEEP][N]);
    }
    if (scanf("%" SCNd64,&v[0]) == 1) return 5;
    return 0;
}
