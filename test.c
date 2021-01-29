#include <stdio.h>


int fileread(char**ptr, ssize_t *len);
int main(int argc, char ** argv)

{
	char *ptr;
	ssize_t len;

	fileread(&ptr, &len);
	//fprintf(stderr, "ptr:%p len:%ld\n", ptr, len);
	return 0;
}
