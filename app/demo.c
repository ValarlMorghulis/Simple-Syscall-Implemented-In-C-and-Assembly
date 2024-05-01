#include"myos.h"

int main(void){
    while(1){
        write("Hello,World!",12);
        sleep(1);
        write("Goodbye,World!",14);
        sleep(1);
    }
}