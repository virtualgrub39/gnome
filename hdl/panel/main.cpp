#include "Vgnome_sim.h"

#include <ncurses.h>
#include <unistd.h>
#include <cstdint>
#include <cstring>

static constexpr float FPS = 60;
static constexpr float FREQ = 10e3;
static constexpr int CYCLES = static_cast<int>(FREQ / FPS);

static void name4(char* out, uint32_t v)
{
    for (int i = 0; i < 4; i++) out[i] = v >> (24 - 8 * i);
    out[4] = 0;
}

static void lamps (int y, const char *label, const int *cnt, int n, bool align)
{
    mvprintw (y, 0, "%-10s", label);
    
    for (int b = n - 1; b >= 0; b -= 1)
    {
        int pct = cnt[b] * 100 / CYCLES;
        addch (pct >= 90 ? 'O' : pct >= 10 ? 'o' : '.');
        addch (' ');
        if (align && (b == 6 || b == 4)) addch(' ');
    }
}

int main (void)
{
    auto *top = new Vgnome_sim;

    initscr (); cbreak(); noecho (); nodelay (stdscr, TRUE); curs_set (0);
    
    int adv = 0, dep = 0;

    for (;;)
    {
        for (int ch; (ch = getch()) != ERR; )
        {
            if (ch > '0' && ch <= '9') top->switches ^= (1u << (9 - (ch - '1')));
            else if (ch == '0') top->switches ^= 0b0000000001;
            else if (ch == 'a') adv = 2;
            else if (ch == 'd') dep = 2;
            else if (ch == 'm') top->manual ^= 1;
            else if (ch == 'p') top->prog   ^= 1;
            else if (ch == 'r') top->rst    ^= 1;   // rst is active-low: 0 = held in reset
            else if (ch == 'q') { endwin(); return 0; }
        }

        top->advance = adv > 0; if (adv) adv--;
        top->deposit = dep > 0; if (dep) dep--;

        int c_ins[10] = {}, c_pc[6] = {}, c_exp[16] = {};

        for (int i = 0; i < CYCLES; ++i)
        {
            top->osc = 0; top->eval();
            top->osc = 1; top->eval();

            uint32_t ins = top->instruction, pc = top->pc, ex = top->expn_regs;
            for (int b = 0; b < 10; b++) c_ins[b] += (ins >> b) & 1;
            for (int b = 0; b < 6;  b++) c_pc[b]  += (pc  >> b) & 1;
            for (int b = 0; b < 16; b++) c_exp[b] += (ex  >> b) & 1;
        }

        erase ();
        mvprintw(0, 0, "GNOME front panel   [0-9] switches  [a] advance   [d] deposit");
        mvprintw(1, 0, "        [m] manual  [p] prog        [r] run/reset [q] quit");
        mvprintw(3, 0, "%-10s", "switches");
        for (int b = 9; b >= 0; b--)
        {
            addch((top->switches >> b) & 1 ? '^' : 'v');
            addch(' ');
            if (b == 6 || b == 4) addch(' ');
        }
        lamps (4, "instr", c_ins, 10, true);

        if (top->prog || top->manual)
        {
            char op[5], bk[5], txt[32];
            name4(op, top->op_name); name4(bk, top->bank_name);
            unsigned ins = top->instruction;
            if      (!strncmp(op, "JMP", 3)) snprintf(txt, sizeof txt, "%s %u", op, ins & 0x3f);
            else if (!strncmp(op, "SKZ", 3) || !strncmp(op, "RTN", 3) || !strncmp(op, "NOP0", 4)
                    || !strncmp(op, "NOPF", 5))
                                            snprintf(txt, sizeof txt, "%s", op);
            else                             snprintf(txt, sizeof txt, "%s %s %u", op, bk, ins & 0xf);
            mvprintw(4, 32, "%-10s%s", "decoded", txt);
        }

        lamps (5, "pc", c_pc, 6, false);
        lamps (6, "expn", c_exp, 16, false);
        mvprintw(8, 0, "mode: %s  %s  %s",
                 top->manual ? "MANUAL" : "auto",
                 top->prog   ? "PROG"   : "run-prog",
                 top->rst    ? "RUNNING" : "RESET");
        refresh ();
        usleep (1.f/FPS * 1e6);
    }

}
