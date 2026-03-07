/**************************************************************************//**
 * @file     CMSDK_CM0.h
 * @brief    CMSIS Cortex-M0 Core Peripheral Access Layer Header File for
 *           Device CMSDK
 * @version  V3.01
 * @date     06. March 2012
 *
 * @note
 * Copyright (C) 2010-2012 ARM Limited. All rights reserved.
 *
 * @par
 * ARM Limited (ARM) is supplying this software for use with Cortex-M
 * processor based microcontrollers.  This file can be freely distributed
 * within development tools that are supporting such ARM based processors.
 *
 * @par
 * THIS SOFTWARE IS PROVIDED "AS IS".  NO WARRANTIES, WHETHER EXPRESS, IMPLIED
 * OR STATUTORY, INCLUDING, BUT NOT LIMITED TO, IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE APPLY TO THIS SOFTWARE.
 * ARM SHALL NOT, IN ANY CIRCUMSTANCES, BE LIABLE FOR SPECIAL, INCIDENTAL, OR
 * CONSEQUENTIAL DAMAGES, FOR ANY REASON WHATSOEVER.
 *
 ******************************************************************************/


#ifndef CMSDK_H
#define CMSDK_H

#ifdef __cplusplus
 extern "C" {
#endif

/** @addtogroup CMSDK_Definitions CMSDK Definitions
  This file defines all structures and symbols for CMSDK:
    - registers and bitfields
    - peripheral base address
    - peripheral ID
    - Peripheral definitions
  @{
*/


/******************************************************************************/
/*                Processor and Core Peripherals                              */
/******************************************************************************/
/** @addtogroup CMSDK_CMSIS Device CMSIS Definitions
  Configuration of the Cortex-M0 Processor and Core Peripherals
  @{
*/
/* ----------------------------- Enumeration Definition ----------------------------------- */
typedef enum
{
  RESET = 0,
  SET = !RESET
}FlagStatus,ITStatus;

typedef enum
{
  DISABLE = 0,
  ENABLE = !DISABLE
}FunctionalState;

typedef enum
{
  ERROR = 0,
  SUCCESS = !ERROR
}ErrorStatus;
/*
 * ==========================================================================
 * ---------- Interrupt Number Definition -----------------------------------
 * ==========================================================================
 */

typedef enum IRQn
{
/******  Cortex-M0 Processor Exceptions Numbers ***************************************************/

/* ToDo: use this Cortex interrupt numbers if your device is a CORTEX-M0 device                   */
  NonMaskableInt_IRQn           = -14,      /*!<  2 Cortex-M0 Non Maskable Interrupt              */
  HardFault_IRQn                = -13,      /*!<  3 Cortex-M0 Hard Fault Interrupt                */
  SVCall_IRQn                   = -5,       /*!< 11 Cortex-M0 SV Call Interrupt                   */
  PendSV_IRQn                   = -2,       /*!< 14 Cortex-M0 Pend SV Interrupt                   */
  SysTick_IRQn                  = -1,       /*!< 15 Cortex-M0 System Tick Interrupt               */

/******  CMSDK Specific Interrupt Numbers *********************************************************/
  UARTRX0_IRQn                  = 0,       /*!< UART 0 RX Interrupt                               */
  UARTTX0_IRQn                  = 1,       /*!< UART 0 TX Interrupt                               */
  UARTRX1_IRQn                  = 2,       /*!< UART 1 RX Interrupt                               */
  UARTTX1_IRQn                  = 3,       /*!< UART 1 TX Interrupt                               */
  UARTRX2_IRQn                  = 4,       /*!< UART 2 RX Interrupt                               */
  UARTTX2_IRQn                  = 5,       /*!< UART 2 TX Interrupt                               */
  PORT0_ALL_IRQn                = 6,       /*!< Port 0, 2 combined Interrupt, Uart3 Rx            */
  PORT1_ALL_IRQn                = 7,       /*!< Port 1,3  combined Interrupt, Uart3 Tx            */
  TIMER0_IRQn                   = 8,       /*!< TIMER 0 Interrupt                                 */
  TIMER1_IRQn                   = 9,       /*!< TIMER 1 Interrupt                                 */
  DUALTIMER_IRQn                = 10,      /*!< Dual Timer Interrupt                              */
  SPI_ALL_IRQn                  = 11,      /*!< SPI Combined interrupt                            */
  UARTOVF_IRQn                  = 12,      /*!< UART combined Overflow Interrupt                  */
  ETHERNET_IRQn                 = 13,      /*!< Ethernet if present                               */
  I2S_IRQn                      = 14,      /*!< Audio I2S Interrupt                               */
  DMA_IRQn                      = 15,      /*!< PL230 DMA Done + Error Interrupt, and Touchscreen */
  PORT0_0_IRQn                  = 16,      /*!< UART4 Rx, GPIO individual pin 0.                  */
  PORT0_1_IRQn                  = 17,      /*!< UART4 Rx, GPIO individual pin 1                   */
  PORT0_2_IRQn                  = 18,      /*!< GPIO 0 individual pin 2                           */
  PORT0_3_IRQn                  = 19,      /*!< GPIO 0 individual pin 3                           */
  PORT0_4_IRQn                  = 20,      /*!< GPIO 0 individual pin 4                           */
  PORT0_5_IRQn                  = 21,      /*!< GPIO 0 individual pin 5                           */
  PORT0_6_IRQn                  = 22,      /*!< GPIO 0 individual pin 6                           */
  PORT0_7_IRQn                  = 23,      /*!< GPIO 0 individual pin 7                           */
  PORT0_8_IRQn                  = 24,      /*!< GPIO 0 individual pin 8                           */
  PORT0_9_IRQn                  = 25,      /*!< GPIO 0 individual pin 9                           */
  PORT0_10_IRQn                 = 26,      /*!< GPIO 0 individual pin 10                          */
  PORT0_11_IRQn                 = 27,      /*!< GPIO 0 individual pin 11                          */
  PORT0_12_IRQn                 = 28,      /*!< GPIO 0 individual pin 12                          */
  PORT0_13_IRQn                 = 29,      /*!< GPIO 0 individual pin 13                          */
  PORT0_14_IRQn                 = 30,      /*!< GPIO 0 individual pin 14                          */
  PORT0_15_IRQn                 = 31,      /*!< GPIO 0 individual pin 15                          */
} IRQn_Type;


/*
 * ==========================================================================
 * ----------- Processor and Core Peripheral Section ------------------------
 * ==========================================================================
 */

/* Configuration of the Cortex-M0 Processor and Core Peripherals */
#define __CM0_REV                 0x0000    /*!< Core Revision r0p0                               */
#define __NVIC_PRIO_BITS          2         /*!< Number of Bits used for Priority Levels          */
#define __Vendor_SysTickConfig    0         /*!< Set to 1 if different SysTick Config is used     */
#define __MPU_PRESENT             0         /*!< MPU present or not                               */

/*@}*/ /* end of group CMSDK_CMSIS */


#include "core_cm0.h"                       /* Cortex-M0 processor and core peripherals           */
#include "system_CMSDK_CM0.h"               /* CMSDK System include file                          */


/******************************************************************************/
/*                Device Specific Peripheral registers structures             */
/******************************************************************************/
/** @addtogroup CMSDK_Peripherals CMSDK Peripherals
  CMSDK Device Specific Peripheral registers structures
  @{
*/

#if defined ( __CC_ARM   )
#pragma anon_unions
#endif

/*--------- Universal Asynchronous Receiver Transmitter (UART) --------*/
typedef struct
{
  __IO   uint32_t  DATA;          /*!< Offset: 0x000 Data Register    (R/W)          */
  __IO   uint32_t  STATE;         /*!< Offset: 0x004 Status Register  (R/W)          */
  __IO   uint32_t  CTRL;          /*!< Offset: 0x008 Control Register (R/W)          */
  union
  {
    __I    uint32_t  INTSTATUS;   /*!< Offset: 0x00C Interrupt Status Register (R/ ) */
    __O    uint32_t  INTCLEAR;    /*!< Offset: 0x00C Interrupt Clear Register ( /W)  */
  };
  __IO   uint32_t  BAUDDIV;       /*!< Offset: 0x010 Baudrate Divider Register (R/W) */
}UART_TypeDef;

/*--------------------- General Purpose Input Output (GPIO) ----------*/
typedef struct
{
  __IO   uint32_t  DATA;          /* Offset: 0x000 (R/W) DATA Register                     */
  __IO   uint32_t  DATAOUT;       /* Offset: 0x004 (R/W) Data Output Latch Register        */
         uint32_t  RESERVED0[2];  /* Offset: 0x010-0x004                                   */
  __IO   uint32_t  OUTENSET;      /* Offset: 0x010 (R/W) Output Enable Set Register        */
  __IO   uint32_t  OUTENCLR;      /* Offset: 0x014 (R/W) Output Enable Clear Register      */
  __IO   uint32_t  ALTFUNCSET;    /* Offset: 0x018 (R/W) Alternate Function Set Register   */
  __IO   uint32_t  ALTFUNCCLR;    /* Offset: 0x01C (R/W) Alternate Function Clear Register */
  __IO   uint32_t  INTENSET;      /* Offset: 0x020 (R/W) Interrupt Enable Set Register     */
  __IO   uint32_t  INTENCLR;      /* Offset: 0x024 (R/W) Interrupt Enable Clear Register   */
  __IO   uint32_t  INTTYPESET;    /* Offset: 0x028 (R/W) Interrupt Type Set Register       */
  __IO   uint32_t  INTTYPECLR;    /* Offset: 0x02C (R/W) Interrupt Type Clear Register     */
  __IO   uint32_t  INTPOLSET;     /* Offset: 0x030 (R/W) Interrupt Polarity Set Register   */
  __IO   uint32_t  INTPOLCLR;     /* Offset: 0x034 (R/W) Interrupt Polarity Clear Register */
  union
  {
    __I    uint32_t  INTSTATUS;    /* Offset: 0x038 (R/ ) Interrupt Status Register        */
    __O    uint32_t  INTCLEAR;     /* Offset: 0x038 ( /W) Interrupt Clear Register         */
  };
         uint32_t RESERVED1[241];    /* Offset : 0x400-0x0038                              */
  __IO   uint32_t MASKLOWBYTE[256];  /* Offset: 0x400 - 0x7FC Lower byte Masked Access Register (R/W) */
  __IO   uint32_t MASKHIGHBYTE[256]; /* Offset: 0x800 - 0xBFC Upper byte Masked Access Register (R/W) */
}GPIO_TypeDef;

/*--------------------- (DMA) ----------*/
typedef struct{
    volatile uint32_t DMA_SRC;
    volatile uint32_t DMA_DST;
    volatile uint32_t DMA_SIZE;
    volatile uint32_t DMA_LEN;
}DMACType;
/* CMSDK_UART DATA Register Definitions */

/******************************************************************************/
/*                   General Purpose Input Output (GPIO)                      */
/******************************************************************************/
/* bit definitions for  DATA register */
#define GPIO_DATA           ((uint32_t) 0x000000FF)  /* GPIO DATA: Data value */

/* bit definitions for DATAOUT register */
#define GPIO_DATAOUT        ((uint32_t) 0x000000FF)  /* GPIO DATAOUT: Data output value */

/* bit definitions for OUTENSET register */
#define GPIO_OUTENSET       ((uint32_t) 0x000000FF)  /* GPIO OUTENSET: Output enable set */

/* bit definitions for OUTENCLR register */
#define GPIO_OUTENCLR       ((uint32_t) 0x000000FF)  /* GPIO OUTENCLR: Output enable clear */

/* bit definitions for ALTFUNCSET register */
#define GPIO_ALTFUNSET      ((uint32_t) 0x000000FF)  /* GPIO ALTFUNCSET: Alternative function set */

/* bit definitions for ALTFUNCCLR register */
#define GPIO_ALTFUNCCLR     ((uint32_t) 0x000000FF)  /* GPIO ALTFUNCCLR: Alternative function clear */

/* bit definitions for INTENSET register */
#define GPIO_INTENSET       ((uint32_t) 0x000000FF)  /* GPIO INTENSET: Interrupt enable set */

/* bit definitions for INTENCLR register */
#define GPIO_INTENCLR       ((uint32_t) 0x000000FF)  /* GPIO INTENCLR: Interrupt enable clear */

/* bit definitions for INTTYPESET register */
#define GPIO_INTTYPESET     ((uint32_t) 0x000000FF)  /* GPIO INTTYPESET: Interrupt type set */

/* bit definitions for INTTYPECLR register */
#define GPIO_INTTYPECLR     ((uint32_t) 0x000000FF)  /* GPIO INTTYPECLR: Interrupt type clear */

/* bit definitions for INTPOLSET register */
#define GPIO_INTPOLSET      ((uint32_t) 0x000000FF)  /* GPIO INTPOLSET: Interrupt polarity set */

/* bit definitions for INTPOLCLR register */
#define GPIO_INTPOLCLR      ((uint32_t) 0x000000FF)  /* GPIO INTPOLCLR: Interrupt polarity clear */

/*  bit definitions for INTSTATUS register */
#define GPIO_INTSTATUS      ((uint32_t) 0x000000FF)  /* GPIO INTSTATUS: Get Interrupt status */

/*  bit definitions for INTCLEAR register */
#define GPIO_INTCLEAR       ((uint32_t) 0x000000FF)  /* GPIO INTCLEAR: Interrupt request clear*/

/*  bit definitions for MASKLOWBYTE register */
#define GPIO_MASKLOWBYTE    ((uint32_t) 0x0000000F)  /* GPIO MASKLOWBYTE: Data for lower byte access */

/*  bit definitions for MASKHIGHBYTE register */
#define GPIO_MASKHIGHBYTE   ((uint32_t) 0x000000F0)  /* GPIO MASKHIGHBYTE: Data for high byte access */


/******************************************************************************/
/*           Universal Asynchronous Receiver Transmitter (UART)               */
/******************************************************************************/
/* bit definitions for DATA register */
#define UART_DATA              ((uint32_t) 0x000000FF) /* UART DATA: Data value */

/* bit definitions for STATE register */
#define UART_STATE_TXBF        ((uint32_t) 0x00000001) /* UART STATE: Tx buffer full    */
#define UART_STATE_RXBF        ((uint32_t) 0x00000002) /* UART STATE: Rx buffer full    */
#define UART_STATE_TXOR        ((uint32_t) 0x00000004) /* UART STATE: Tx buffer overrun */
#define UART_STATE_RXOR        ((uint32_t) 0x00000008) /* UART STATE: Rx buffer overrun */

/* bit definitions for CTRL register */
#define UART_CTRL_TXEN         ((uint32_t) 0x00000001) /* UART CTRL: TX enable                           */
#define UART_CTRL_RXEN         ((uint32_t) 0x00000002) /* UART CTRL: RX enable           
            */
#define UART_CTRL_TXIRQEN      ((uint32_t) 0x00000004) /* UART CTRL: TX interrupt enable 
            */
#define UART_CTRL_RXIRQEN      ((uint32_t) 0x00000008) /* UART CTRL: RX interrupt enable 
            */
#define UART_CTRL_TXORIRQEN    ((uint32_t) 0x00000010) /* UART CTRL: TX overrun interrupt enable         */
#define UART_CTRL_RXORIRQEN    ((uint32_t) 0x00000020) /* UART CTRL: RX overrun interrupt enable         */
#define UART_CTRL_HSTM         ((uint32_t) 0x00000040) /* UART CTRL: High-speed test mode for TX enable  */

/* bit definitions for INTSTATUS register */
#define UART_INTSTATUS_TXIRQ    ((uint32_t) 0x00000001) /* UART INTCLEAR: Get TX interrupt status         */
#define UART_INTSTATUS_RXIRQ    ((uint32_t) 0x00000002) /* UART INTCLEAR: Get RX interrupt status         */
#define UART_INTSTATUS_TXORIRQ  ((uint32_t) 0x00000004) /* UART INTCLEAR: Get TX overrun interrupt status */
#define UART_INTSTATUS_RXORIRQ  ((uint32_t) 0x00000008) /* UART INTCLEAR: Get RX overrun interrupt status */

/* bit definitions for INTCLEAR register */
#define UART_INTCLEAR_TXIRQ    ((uint32_t) 0x00000001) /* UART INTCLEAR: Clear TX interrupt         */
#define UART_INTCLEAR_RXIRQ    ((uint32_t) 0x00000002) /* UART INTCLEAR: Clear RX interrupt         */
#define UART_INTCLEAR_TXORIRQ  ((uint32_t) 0x00000004) /* UART INTCLEAR: Clear TX overrun interrupt */
#define UART_INTCLEAR_RXORIRQ  ((uint32_t) 0x00000008) /* UART INTCLEAR: Clear RX overrun interrupt */

/* bit definitions for BAUDDIV register */
#define UART_BAUDDIV           ((uint32_t) 0x000FFFFF) /* UART BAUDDIV: Baud rate divider*/

#if defined ( __CC_ARM   )
#pragma no_anon_unions
#endif

/*@}*/ /* end of group CMSDK_Peripherals */


/******************************************************************************/
/*                         Peripheral memory map                              */
/******************************************************************************/
/** @addtogroup CMSDK_MemoryMap CMSDK Memory Mapping
  @{
*/

/* Peripheral and SRAM base address */
#define AHBL1_M0_BASE   	((uint32_t)0x00000000) //FLASH
#define AHBL1_M1_BASE   	((uint32_t)0x20000000) //RAM
#define AHBL1_M2_BASE   	((uint32_t)0x30000000) //GPIO
#define AHBL1_M3_BASE   	((uint32_t)0x30800000) //DMA
#define AHBL1_M4_BASE   	((uint32_t)0x40000000) //AHB2APB
#define AHBL1_M5_BASE   	((uint32_t)0x60000000) //Rev

#define APB_M0_BASE   		(AHBL1_M4_BASE + 0x0000)//0x40000000)//TIM0
#define APB_M1_BASE   		(AHBL1_M4_BASE + 0x1000)//0x40001000)//TIM1
#define APB_M2_BASE   		(AHBL1_M4_BASE + 0x2000)//0x40002000)//TIM2
#define APB_M3_BASE   		(AHBL1_M4_BASE + 0x3000)//0x40003000)//REV
#define APB_M4_BASE   		(AHBL1_M4_BASE + 0x4000)//0x40004000)//UART0
#define APB_M5_BASE   		(AHBL1_M4_BASE + 0x5000)//0x40005000)//UART1
#define APB_M6_BASE   		(AHBL1_M4_BASE + 0x6000)//0x40006000)//REV
#define APB_M7_BASE   		(AHBL1_M4_BASE + 0x7000)//0x40007000)//REV
#define APB_M8_BASE   		(AHBL1_M4_BASE + 0x8000)//0x40008000)//WDT
#define APB_M9_BASE   		(AHBL1_M4_BASE + 0x9000)//0x40009000)//REV

#define DMA_BASE       	  AHBL1_M3_BASE
#define UART0_BASE        APB_M4_BASE
#define GPIO_BASE 				AHBL1_M2_BASE

#define GPIO 							((GPIO_TypeDef 			*) GPIO_BASE)
#define UART0             ((UART_TypeDef 			*) UART0_BASE)
#define DMAC 							((DMACType 					*) DMA_BASE)

#ifdef __cplusplus
}
#endif

#endif  /* CMSDK_H */
