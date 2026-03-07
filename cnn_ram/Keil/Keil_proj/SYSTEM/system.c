#include "CMSDK_CM0.h"
#include "core_cm0.h"
#include "stdint.h"
#include <string.h>

void Set_SysTick_CTRL(uint32_t ctrl)
{
	SysTick->CTRL = ctrl;
}

void Set_SysTick_LOAD(uint32_t load)
{
	SysTick->LOAD = load;
}

uint32_t Read_SysTick_VALUE(void)
{
	return(SysTick->VAL);
}

//void Set_SysTick_CALIB(uint32_t calib)
//{
//	SysTick->CALIB = calib;
//}

void Set_SysTick_VALUE(uint32_t value)
{
	SysTick->VAL = value;
}

uint32_t Timer_Ini(void)
{
	SysTick->CTRL = 0;
	SysTick->LOAD = 0xffffff;
	SysTick->VAL = 0;
	SysTick->CTRL = 0x5;
	while(SysTick->VAL == 0);
	return(SysTick->VAL);
}
uint8_t Timer_Stop(uint32_t *duration_t,uint32_t start_t)
{
	uint32_t stop_t;
	stop_t = SysTick->VAL;
	if((SysTick->CTRL & 0x10000) == 0)
	{
		*duration_t = start_t - stop_t;
		return(1);
	}
	else
	{
		return(0);
	}
}

void delay(uint32_t time)
{
	Set_SysTick_CTRL(0);
	Set_SysTick_LOAD(time);
	Set_SysTick_VALUE(0);
	Set_SysTick_CTRL(0x7);
	__wfi();
}
void delay_us(uint32_t time)
{
	Set_SysTick_CTRL(0);
	Set_SysTick_LOAD(time*100);
	Set_SysTick_VALUE(0);
	Set_SysTick_CTRL(0x7);
	__wfi();
}
void delay_ms(uint32_t time)
{
	Set_SysTick_CTRL(0);
	Set_SysTick_LOAD(time*100000);
	Set_SysTick_VALUE(0);
	Set_SysTick_CTRL(0x7);
	__wfi();
}

void mem8_write(uint32_t sram_addr,uint8_t data)
{
	*(__IO uint8_t*)sram_addr = data;
}

uint8_t mem8_read(uint32_t sram_addr)
{
	return *(__IO uint8_t*)sram_addr;
}

void mem16_write(uint32_t sram_addr,uint16_t data)
{
	*(__IO uint16_t*)sram_addr = data;
}

uint16_t mem16_read(uint32_t sram_addr)
{
	return *(__IO uint16_t*)sram_addr;
}

void mem32_write(uint32_t sram_addr,uint32_t data)
{
	*(__IO uint32_t*)sram_addr = data;
}

uint32_t mem32_read(uint32_t sram_addr)
{
	return *(__IO uint32_t*)sram_addr;
}
