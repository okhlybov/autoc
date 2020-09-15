PROG = test

SRC = $(PROG)_auto.c
HDR = $(PROG)_auto.h

all : $(PROG)

CFLAGS = -g

$(PROG) : $(SRC:.c=.o)
	$(CC) $(CFLAGS) -o $@ $^

run : all
	./$(PROG)

$(SRC) $(HDR) : test.rb test_*.rb
	 ruby -I. -I../lib $<
	-sed -i '/^\s*$$/d' $(SRC)
	-sed -i '/^\s*$$/d' $(HDR)
	-astyle -n $(SRC) $(HDR)