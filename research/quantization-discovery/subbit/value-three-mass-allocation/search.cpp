#include <array>
#include <cmath>
#include <cstdio>
#include <limits>
using namespace std;

// Head 0..15, choices 0=4095, 1=255, 2=15. G indexes the 32 nonzero deltas.
array<array<double, 32>, 32> g;
array<array<long long, 3>, 16> cost;
double denominator, budget;
long long best_cost = numeric_limits<long long>::max();
double best_error = 0;
array<int, 16> choice{}, best_choice{};
unsigned long long leaves = 0;
bool allow15 = true;

void visit(int head, double error, long long work) {
    if (work >= best_cost) return;
    if (head == 16) {
        ++leaves;
        if (error <= budget*denominator) {
            best_cost = work;
            best_error = error/denominator;
            best_choice = choice;
        }
        return;
    }
    for (int arm : {2, 1, 0}) {
        if (arm == 2 && !allow15) continue;
        long long next_work = work + cost[head][arm];
        if (next_work >= best_cost) continue;
        double next_error = error;
        if (arm) {
            int idx = 2*head + arm-1;
            next_error += g[idx][idx];
            for (int h=0; h<head; ++h)
                if (choice[h]) next_error += 2*g[idx][2*h+choice[h]-1];
        }
        choice[head] = arm;
        visit(head+1, next_error, next_work);
    }
}

int main(int argc, char **argv) {
    if ((argc != 2 && argc != 3) || sscanf(argv[1], "%lf", &budget) != 1) return 2;
    allow15 = argc == 2;
    if (scanf("%lf", &denominator) != 1) return 2;
    for (auto &row : cost) for (auto &c : row) if (scanf("%lld", &c) != 1) return 2;
    for (auto &row : g) for (auto &v : row) if (scanf("%lf", &v) != 1) return 2;
    visit(0, 0., 0);
    printf("{\"work\":%lld,\"train_error\":%.12g,\"leaves\":%llu,\"arms\":[", best_cost, best_error, leaves);
    for (int i=0; i<16; ++i) printf("%s%d", i ? "," : "", best_choice[i]);
    puts("]}");
}
