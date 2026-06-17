#include <stdio.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

typedef unsigned char u8;
typedef unsigned short u16;
typedef unsigned int u32;

typedef struct {
    u8 bji[3];
    u8 oem[8];
    u16 bps;
    u8 spc;
    u16 rs;
    u8 fc;
    u16 dec;
    u16 ts;
    u8 mdt;
    u16 spf;
    u16 spt;
    u16 heads;
    u32 hs;
    u32 lsc;
    u8 dn;
    u8 res;
    u8 sig;
    u32 vid;
    u8 vl[11];
    u8 sid[8];
} __attribute__((packed)) BootSector;

typedef struct {
    u8 name[11];
    u8 attrs;
    u8 res;
    u8 ctt;
    u16 ct;
    u16 cd;
    u16 ad;
    u16 fch;
    u16 mt;
    u16 md;
    u16 fcl;
    u32 size;
} __attribute__((packed)) FatEntry;

BootSector bs;
u8* fat = NULL;
FatEntry* rootDir = NULL;
u32 rootDirEnd;

bool read_boot_sector(FILE* disk) {
    return fread(&bs, sizeof(bs), 1, disk) == 1;
}

bool read_sectors(FILE* disk, u32 lba, u32 count, void* bufOut) {
    bool ok = true;
    ok = ok && (fseek(disk, lba * bs.bps, SEEK_SET) == 0);
    ok = ok && (fread(bufOut, bs.bps, count, disk) == count);
    return ok;
}

bool read_fat(FILE* disk) {
    fat = (u8*)malloc(bs.spf * bs.bps);
    return read_sectors(disk, bs.rs, bs.spf, fat);
}

bool read_root(FILE* disk) {
    u32 lba = bs.rs + (u32)bs.spf * bs.fc;
    u32 size = sizeof(FatEntry) * bs.dec;
    u32 sectors = (size / bs.bps);
    if (size % bs.bps > 0) sectors++;
    rootDirEnd = lba + sectors;
    rootDir = (FatEntry*)malloc(sectors * bs.bps);
    return read_sectors(disk, lba, sectors, rootDir);
}

FatEntry* find_file(const char* name) {
    for (u32 i = 0; i < bs.dec; i++) {
        if (memcmp(name, rootDir[i].name, 11) == 0) return &rootDir[i];
    }

    return NULL;
}

bool read_file(FatEntry* fileEntry, FILE* disk, u8* outBuf) {
    bool ok = true;
    u16 currentCluster = fileEntry->fcl;

    do {
        u32 lba = rootDirEnd + (currentCluster - 2) * bs.spc;
        ok = ok && read_sectors(disk, lba, bs.spc, outBuf);
        outBuf += bs.spc * bs.bps;
        u32 fatIndex = currentCluster * 3 / 2;
        if (currentCluster % 2 == 0) currentCluster = (*(u16*)(fat + fatIndex)) & 0x0FFF;
        else currentCluster = (*(u16*)(fat + fatIndex)) >> 4;
    } while (ok && currentCluster < 0x0FF8);
    return ok;
}

int main(int argc, char** argv) {
    if (argc < 3) {
        printf("Syntax: %s <disk image> <filename>\n", argv[0]);
        return -1;
    }

    FILE* disk = fopen(argv[1], "rb");
    if (!disk) {
        fprintf(stderr, "Cannot open disk image %s!\n", argv[1]);
        return -1;
    }

    if (!read_boot_sector(disk)) {
        fprintf(stderr, "Cannot read disk image %s!\n", argv[1]);
        return -2;
    }

    if (!read_fat(disk)) {
        fprintf(stderr, "Cannot read FAT!\n");
        free(fat);
        return -3;
    }

    if (!read_root(disk)) {
        fprintf(stderr, "Could not read root directory!\n");
        free(fat);
        free(rootDir);
        return -4;
    }

    FatEntry* fileEntry = find_file(argv[2]);
    if (!fileEntry) {
        fprintf(stderr, "Could not find file %s!\n", argv[2]);
        free(fat);
        free(rootDir);
        return -5;
    }

    u8* buf = (u8*)malloc(fileEntry->size + bs.bps);
    if (!read_file(fileEntry, disk, buf)) {
        fprintf(stderr, "Could not read file %s!\n", argv[2]);
        free(fat);
        free(rootDir);
        free(buf);
        return -5;
    }

    for (size_t i = 0; i < fileEntry->size; i++) {
        if (isprint(buf[i])) fputc(buf[i], stdout);
        else printf("<%02x>", buf[i]);
    }
    printf("\n");

    free(fat);
    free(rootDir);
    free(buf);
    return 0;
}