#pragma once
#include <atomic>
#include <cstdio>
#include <cctype>
#include <chrono>
#include <filesystem>
#include <fstream>
#include <sstream>
#include <string>
#include <thread>
#include <vector>

namespace kbtelemetry {
namespace fs = std::filesystem;
inline long long now_ns() {
    return std::chrono::duration_cast<std::chrono::nanoseconds>(
        std::chrono::steady_clock::now().time_since_epoch()).count();
}
inline std::string text(const fs::path &p) {
    std::ifstream f(p); std::ostringstream s; s << f.rdbuf(); return s.str();
}
inline long long number(const fs::path &p) {
    std::ifstream f(p); long long v=-1; f >> v; return v;
}
inline std::string client_snapshot() {
    std::ostringstream o;o<<"{\"scope\":\"Visible processes with any DRM device open; not a measure of activity. Permission skips recorded.\",\"clients\":[";
    bool first=true;int skipped=0;std::error_code ec;
    for(const auto &p:fs::directory_iterator("/proc",ec)) {
        std::string pid=p.path().filename().string();
        if(pid.empty()||!std::isdigit(static_cast<unsigned char>(pid[0])))continue;
        std::error_code err;bool gpu=false;
        fs::directory_iterator fds(p.path()/"fd",err);
        if(err){++skipped;continue;}
        for(const auto &fd:fds) {
            std::error_code e;auto target=fs::read_symlink(fd.path(),e).string();
            if(!e && target.find("/dev/dri/")==0){gpu=true;break;}
        }
        if(gpu){if(!first)o<<',';first=false;
            o<<"{\"pid\":"<<pid<<",\"comm\":\"";
            for(char c:text(p.path()/"comm"))if(c>=32&&c!='\"'&&c!='\\')o<<c;
            o<<"\"}";}
    }
    o<<"],\"unreadable_fd_directories\":"<<skipped<<'}';return o.str();
}
struct Sample {
    long long begin_ns, end_ns, gfx_hz=-1, temperature_mc=-1, power_uw=-1, busy_percent=-1;
    double load1=-1;
};
class Recorder {
    fs::path device, hwmon;
    std::atomic<bool> stop{false};
    std::thread worker;
    std::vector<Sample> samples;
public:
    Recorder(int domain, int bus, int dev) {
        char address[40]; snprintf(address,sizeof address,"%04x:%02x:%02x.0",domain,bus,dev);
        device=fs::path("/sys/bus/pci/devices")/address;
        std::error_code ec;
        for(const auto &e:fs::directory_iterator(device/"hwmon",ec)) {
            if(text(e.path()/"name").find("amdgpu")!=std::string::npos) {hwmon=e.path();break;}
        }
        worker=std::thread([this]{
            while(!stop.load()) {
                Sample s{};s.begin_ns=now_ns();
                if(!hwmon.empty()) {
                    s.gfx_hz=number(hwmon/"freq1_input");
                    s.temperature_mc=number(hwmon/"temp1_input");
                    s.power_uw=number(hwmon/"power1_input");
                }
                s.busy_percent=number(device/"gpu_busy_percent");
                std::ifstream load("/proc/loadavg");load>>s.load1;
                s.end_ns=now_ns();samples.push_back(s);
                std::this_thread::sleep_for(std::chrono::milliseconds(5));
            }
        });
    }
    void finish() {stop.store(true);if(worker.joinable())worker.join();}
    ~Recorder(){finish();}
    std::string json() {
        finish();std::ostringstream o;
        o << "{\"device_sysfs\":\""<<device.string()<<"\",\"frequency_label\":\"";
        std::string label=hwmon.empty()?"unavailable":text(hwmon/"freq1_label");
        for(char c:label)if(c!='\n'&&c!='\r'&&c!='\"'&&c!='\\')o<<c;
        o << "\",\"sampling\":\"Host snapshots every approximately 5ms; -1 means unavailable. Not per-instruction cycles or proof of exclusive GPU use.\",\"samples\":[";
        bool first=true;for(const auto &s:samples){if(!first)o<<',';first=false;
            o<<"{\"begin_ns\":"<<s.begin_ns<<",\"end_ns\":"<<s.end_ns
             <<",\"gfx_hz\":"<<s.gfx_hz<<",\"temperature_mc\":"<<s.temperature_mc
             <<",\"power_uw\":"<<s.power_uw<<",\"busy_percent\":"<<s.busy_percent
             <<",\"host_load1\":"<<s.load1<<'}';}
        o<<"]}";return o.str();
    }
};
}
