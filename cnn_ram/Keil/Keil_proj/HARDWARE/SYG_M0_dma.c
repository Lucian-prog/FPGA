#include "SYG_M0_dma.h"
#include <string.h>

void DMA(int src,int dst,int size,int len)
{
	DMAC -> DMA_SRC = src;
	DMAC -> DMA_DST = dst;
	DMAC -> DMA_SIZE = size;
	DMAC -> DMA_LEN = len;
	//__wfe();
}