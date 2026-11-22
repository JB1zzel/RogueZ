/* zbank - zrun with a bankable top segment, for testing far calls.
   $0000-$BFFF is fixed RAM/ROM; $C000-$FFFF shows one of 16 banks, chosen by
   OUT ($D3),A (the Blink's SR3 port; on a real Z88 the code uses OS_Mpb).
   usage: zbank [-s START] [-d ADDR:LEN:file] file@ADDR | file@B:ADDR ...
     file@B:ADDR  load into bank B (hex) at ADDR ($C000-$FFFF)
   Runs to HALT; prints T-states, the bank bound at the end, and every OUT
   ($FE),A marker.  Writes to a bank's area in ROM-marked banks are refused. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "Z80.h"
static byte low[0xC000], bank[16][0x4000];
static int sel; static long long t; static long long writes_to_rom;
static int markers[256], nmark;
void WrZ80(register word A, register byte V) {
  if (A < 0xC000) low[A] = V; else { writes_to_rom++; } }
byte RdZ80(register word A) { return A < 0xC000 ? low[A] : bank[sel][A - 0xC000]; }
void OutZ80(register word P, register byte V) {
  if ((P & 0xFF) == 0xD3) sel = V & 15;
  if ((P & 0xFF) == 0xFE && nmark < 256) markers[nmark++] = V; }
byte InZ80(register word P) { (void) P; return 0xFF; }
word LoopZ80(register Z80 *R) { (void) R; return INT_NONE; }
void PatchZ80(register Z80 *R) { (void) R; }
int main(int argc, char **argv) {
  int start = -1; char *dumps[16]; int nd = 0;
  for (int i = 1; i < argc; i++) {
    char *a = argv[i];
    if (!strcmp(a, "-s") && i + 1 < argc) start = strtoul(argv[++i], 0, 16);
    else if (!strcmp(a, "-d") && i + 1 < argc) dumps[nd++] = argv[++i];
    else { char *at = strrchr(a, '@'); if (!at) { fprintf(stderr, "%s: need file@ADDR\n", a); return 2; }
      *at = 0; char *col = strchr(at + 1, ':'); int b = -1; unsigned ad;
      if (col) { b = strtoul(at + 1, 0, 16); ad = strtoul(col + 1, 0, 16); } else ad = strtoul(at + 1, 0, 16);
      FILE *f = fopen(a, "rb"); if (!f) { perror(a); return 2; }
      size_t n = b < 0 ? fread(low + ad, 1, 0xC000 - ad, f) : fread(bank[b] + (ad - 0xC000), 1, 0x10000 - ad, f);
      fclose(f); if (start < 0 && b < 0) start = ad; (void) n; } }
  Z80 cpu; memset(&cpu, 0, sizeof cpu); ResetZ80(&cpu); cpu.PC.W = start; cpu.SP.W = 0xBFFE;
  cpu.IPeriod = 0; cpu.IRequest = INT_NONE;
  long long n = 0; while (!(cpu.IFF & IFF_HALT) && n < 200000000LL) { t += 1 - ExecZ80(&cpu, 1); n++; }
  printf("%s after %lld T-states, PC=%04X, bank %d bound, %lld writes to $C000+\n",
         (cpu.IFF & IFF_HALT) ? "HALT" : "STOPPED", t, cpu.PC.W, sel, writes_to_rom);
  printf("markers:"); for (int k = 0; k < nmark; k++) printf(" %d", markers[k]); printf("\n");
  for (int k = 0; k < nd; k++) { char *s = dumps[k]; unsigned ad = strtoul(s, &s, 16); unsigned len = strtoul(s + 1, &s, 16);
    FILE *f = fopen(s + 1, "wb"); if (f) { fwrite(low + ad, 1, len, f); fclose(f); } }
  return (cpu.IFF & IFF_HALT) ? 0 : 1; }
