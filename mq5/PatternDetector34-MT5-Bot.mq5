//+------------------------------------------------------------------+
//|                                    PatternDetector34-MT5-Bot.mq5 |
//|                                                  Denis Kislitsyn |
//|                                             https://kislitsyn.me |
//+------------------------------------------------------------------+

#include <Arrays\ArrayObj.mqh>

#include "Include\DKStdLib\TradingManager\CDKPositionInfo.mqh"
#include "Include\DKStdLib\TradingManager\CDKSymbolInfo.mqh"
#include <Trade\Trade.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\HistoryOrderInfo.mqh>

#include "Include\DKStdLib\Common\DKStdLib.mqh"
#include "Include\DKStdLib\Logger\DKLogger.mqh"
#include "Include\DKStdLib\NewBarDetector\DKNewBarDetector.mqh" 
//#include "Include\DKStdLib\Analysis\DKChartAnalysis.mqh"
//#include "Include\DKStdLib\Drawing\DKChartDraw.mqh"

enum ENUM_ARROW_POS {
  ARROW_POS_HIT,          // Возврат в уровень
  ARROW_POS_CONFIRM       // Подтверждения по MA
};

enum ENUM_CLOSE_MODE {
  CLOSE_MODE_FIXED_TIME,    // Фиксированное время, мин.
  CLOSE_MODE_EXPIRATION     // Экспирация
};

#property script_show_inputs

input  group              "0. ТОРГОВЛЯ"
//input  ENUM_MM_TYPE       InpMMType                       = ENUM_MM_TYPE_FIXED_LOT;           // 0.01: Тип MM
input  double             InpMMValue                        = 0.1;                              // 0.01: Лот
input  ENUM_CLOSE_MODE    InpCloseMode                      = CLOSE_MODE_FIXED_TIME;            // 0.02A: Режим закрытия сделок
input  uint               InpFixedCloseAfterMin             = 5;                                // 0.02B: Фиксированное время в сделке, мин
input  ENUM_TIMEFRAMES    InpExpCloseTF                     = PERIOD_M5;                        // 0.02C: Таймфрейм определения экспирации
input  uint               InpExpCloseAddBarWhenLessToCloseMin = 3;                              // 0.02D: Мин.время от стрелки до конца бара экспирации, мин
       ulong              InpSlippage                       = 2;                                // 0.04: Макс. проскальзование операций, пунктов

input  group              "1. НАСТРОЙКИ ПАТТЕРНОВ И УРОВНЕЙ"
input  ENUM_TIMEFRAMES    InpTFPatternDetection             = PERIOD_M5;                        // 1.01: Таймферм определения паттернов и уровней 
input  uint               InpDepthHour                      = 5;                                // 1.02: Глубина определения паттернов в прошлое, часов

input  group              "2. НАСТРОЙКИ СИГНАЛОВ"
input  ENUM_TIMEFRAMES    InpTFSignalDetection              = PERIOD_M1;                        // 2.01: Таймферм определения сигнала по паттерну 

input  group              "3. ВЕРХНИЙ УРОВЕНЬ"
input  bool               InpPattern01Active                = true;                             // 3.01: Включен
input  string             InpPattern01BarList               = "TH;TOCHL;TOCHL";                 // 3.02: Комбинации цен баров для определения уровня
input  uint               InpPattern01K                     = 50;                               // 3.03: Диапазон K, пунктов (макс. отклонение цен баров паттерна)
input  uint               InpPattern01N                     = 100;                              // 3.04: Расстояние N, пунктов (мин. от уровня до закр. пробития)
input  uint               InpPattern01S                     = 120;                              // 3.05: Макс. время S, мин. (от пробития до возврата в уровень)
input  uint               InpPattern01С                     = 5;                                // 3.06: Макс. время C, мин. (от возврата до сигнала)
input  int                InpPattern01LevelShiftPoint       = 0;                                // 3.07: Доп. сдвиг уровня после паттерна, пунктов (0-откл.)
input  bool               InpPattern01ExtremeLevel          = false;                            // 3.08: Уровень по экстремуму паттерна (иначе по первому бару)
input  bool               InpPattern01LHLastBarCHitsExtreme = true;                             // 3.09: CLOSE пробивающего выше HIGH (если паттерн с HIGH)
input  uint               InpPattern01CheckBTRExtremeFrom   = 0;                                // 3.10: Первый № бара паттерна, где LOW д.б. выше прошлого 
input  uint               InpPattern01CheckBTRExtremeTo     = 0;                                // 3.11: Последний № бара паттерна, где LOW д.б. выше прошлого 
input  uint               InpPattern01CheckCloseFromBar     = 0;                                // 3.12: Закрытие ниже уровня начиная с № бара (0-откл)
input  uint               InpPattern01CheckCloseTolerancePnt= 0;                                // 3.13: Закрытие ниже уровня допуск (0-откл), пункт
input  bool               InpPattern01MA20Check             = true;                             // 3.14: Короткая MA: Проверить положение цены по после возврата
input  int                InpPattern01MA20Period            = 20;                               // 3.15: Короткая MA: Период
input  int                InpPattern01MA20Shift             = 0;                                // 3.16: Короткая MA: Сдвиг
input  ENUM_MA_METHOD     InpPattern01MA20Method            = MODE_SMA;                         // 3.17: Короткая MA: Метод
input  ENUM_APPLIED_PRICE InpPattern01MA20AppliedPrice      = PRICE_CLOSE;                      // 3.18: Короткая MA: Цена
input  bool               InpPattern01MA100Check            = true;                             // 3.19: Длинная MA: Проверить направление после возврата
input  int                InpPattern01MA100Period           = 100;                              // 3.20: Длинная MA: Период
input  int                InpPattern01MA100Shift            = 0;                                // 3.21: Длинная MA: Сдвиг
input  ENUM_MA_METHOD     InpPattern01MA100Method           = MODE_SMA;                         // 3.22: Длинная MA: Метод
input  ENUM_APPLIED_PRICE InpPattern01MA100AppliedPrice     = PRICE_CLOSE;                      // 3.23: Длинная MA: Цена
input  ENUM_ARROW_POS     InpPattern01ArrowPos              = ARROW_POS_CONFIRM;                // 3.24: Момент появления стрелки

input  group              "4. НИЖНИЙ УРОВЕНЬ"
input  bool               InpPattern02Active                = true;                             // 4.01: Включен
input  string             InpPattern02BarList               = "BL;BOCLH;BOCLH";                 // 4.02: Комбинации цен баров для определения уровня
input  uint               InpPattern02K                     = 50;                               // 4.03: Диапазон K, пунктов (макс. отклонение цен баров паттерна)
input  uint               InpPattern02N                     = 100;                              // 4.04: Расстояние N, пунктов (мин. от уровня до закр. пробития)
input  uint               InpPattern02S                     = 120;                              // 4.05: Макс. время S, мин. (от пробития до возврата в уровень)
input  uint               InpPattern02С                     = 5;                                // 4.06: Макс. время C, мин. (от возврата до сигнала)
input  int                InpPattern02LevelShiftPoint       = 0;                                // 4.07: Доп. сдвиг уровня после паттерна, пунктов (0-откл.)
input  bool               InpPattern02ExtremeLevel          = false;                            // 4.08: Уровень по экстремуму паттерна (иначе по первому бару)
input  bool               InpPattern02LHLastBarCHitsExtreme = true;                             // 4.09: CLOSE пробивающего ниже HIGH (если паттерн с LOW)
input  uint               InpPattern02CheckBTRExtremeFrom   = 0;                                // 4.10: Первый № бара паттерна, где HIGH д.б. ниже прошлого 
input  uint               InpPattern02CheckBTRExtremeTo     = 0;                                // 4.11: Последний № бара паттерна, где HIGH д.б. ниже прошлого 
input  uint               InpPattern02CheckCloseFromBar     = 0;                                // 4.12: Закрытие выше уровня начиная с № бара (0-откл)
input  uint               InpPattern02CheckCloseTolerancePnt= 0;                                // 4.13: Закрытие выше уровня допуск (0-откл), пункт
input  bool               InpPattern02MA20Check             = true;                             // 4.14: Короткая MA: Проверить положение цены по после возврата
input  int                InpPattern02MA20Period            = 20;                               // 4.15: Короткая MA: Период
input  int                InpPattern02MA20Shift             = 0;                                // 4.16: Короткая MA: Сдвиг
input  ENUM_MA_METHOD     InpPattern02MA20Method            = MODE_SMA;                         // 4.17: Короткая MA: Метод
input  ENUM_APPLIED_PRICE InpPattern02MA20AppliedPrice      = PRICE_CLOSE;                      // 4.18: Короткая MA: Цена
input  bool               InpPattern02MA100Check            = true;                             // 4.19: Длинная MA: Проверить направление после возврата
input  int                InpPattern02MA100Period           = 100;                              // 4.20: Длинная MA: Период
input  int                InpPattern02MA100Shift            = 0;                                // 4.21: Длинная MA: Сдвиг
input  ENUM_MA_METHOD     InpPattern02MA100Method           = MODE_SMA;                         // 4.22: Длинная MA: Метод
input  ENUM_APPLIED_PRICE InpPattern02MA100AppliedPrice     = PRICE_CLOSE;                      // 4.23: Длинная MA: Цена
input  ENUM_ARROW_POS     InpPattern02ArrowPos              = ARROW_POS_CONFIRM;                // 4.24: Момент появления стрелки

input  group              "5. ФИЛЬТР ПО ВРЕМЕНИ"
input int                 InpTimeAddHours                   = 3;                                // 5.01: Сдвиг времени в часах
input string              InpTimeMonday_Not_Arrow           = "08:30-08:55,10:30-12:15";        // 5.02: Понедельник не торговые периоды (максимум 20 периодов)
input string              InpTimeTuesday_Not_Arrow          = "08:30-08:55,10:30-12:15";        // 5.03: Вторник не торговые периоды (максимум 20 периодов)
input string              InpTimeWednesday_Not_Arrow        = "08:30-08:55,10:30-12:15";        // 5.04: Среда не торговые периоды (максимум 20 периодов)
input string              InpTimeThursday_Not_Arrow         = "08:30-08:55,10:30-12:15";        // 5.05: Четверг не торговые периоды (максимум 20 периодов)
input string              InpTimeFriday_Not_Arrow           = "08:30-08:55,10:30-12:15";        // 5.06: Пятница не торговые периоды (максимум 20 периодов)
input string              InpTimeEveryDay_Not_Arrow         = "00:00-01:00";                    // 5.07: Не торговые периоды на каждый день (максимум 20 периодов)
input string              InpTimeEveryHour_Not_Arrow        = "00-10";                          // 5.08: Не торговые периоды на каждый час (максимум 20 периодов)

input  group              "6. ГРАФИКА"
sinput bool               InpPatternDraw                    = true;                             // 6.01A: Рисовать уровни
sinput bool               InpPatternDrawNonHit              = false;                            // 6.01B: Рисовать уровни без возврата в уровень
sinput uint               InpPattern01ArrowCode             = 233;                              // 6.02: ВЕРХ: Код символа стрелки
sinput uint               InpPattern02ArrowCode             = 234;                              // 6.03: НИЗ: Код символа стрелки
sinput uint               InpPattern01StartCode             = 167;                              // 6.04: ВЕРХ: Код символа начала и подтверждения паттерна
sinput uint               InpPattern02StartCode             = 167;                              // 6.05: НИЗ: Код символа начала и подтверждения паттерна
sinput string             InpPattern01Name                  = "ВЕРХ";                           // 6.06: ВЕРХ: Подпись линий уровня
sinput string             InpPattern02Name                  = "НИЗ";                            // 6.07: НИЗ: Подпись линий уровня
sinput color              InpPattern01Color                 = clrGreen;                         // 6.08: ВЕРХ: Цвет
sinput color              InpPattern02Color                 = clrRed;                           // 6.09: НИЗ: Цвет

input  group              "7. ПРОЧЕЕ"
sinput LogLevel           InpLogLevel                       = LogLevel(INFO);                  // 7.01: Уровень логирования
sinput int                InpMagic                          = 20240314;                         // 7.02: Magic
       string             InpGlobalPrefix                   = "PD34BW";  

DKLogger logger;

int ind_handle_pd34;

CAccountInfo  accountInfo;
CDKSymbolInfo   symbolInfo;
CTrade    tradeInfo;
CPositionInfo positionInfo;
CHistoryOrderInfo historyInfo;

double arrow_up_buffer[];
double arrow_down_buffer[];

datetime arrow_up_last_dt;
datetime arrow_down_last_dt;

DKNewBarDetector* new_bar_detector;

int up_open_cnt, down_open_cnt;
int up_close_cnt, down_close_cnt;


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()  {
  logger.Name = InpGlobalPrefix;
  logger.Level = InpLogLevel;
  logger.Format = "%name%:[%level%] %message%";
  //if(MQL5InfoInteger(MQL5_DEBUGGING)) logger.Level = LogLevel(DEBUG);
  
  //string expar = (string)InputMagic;
  //datetime expiration = StringToTime(expar);
  //if (TimeCurrent() > StringToTime((string)InputMagic) + 32 * 24 * 60 * 60) {
  //  MessageBox("Developer version is expired", "Error", MB_OK | MB_ICONERROR);
  //  return(INIT_FAILED);
  //}

  // Проверим режим счета. Нужeн ОБЯЗАТЕЛЬНО ХЕДЖИНГОВЫЙ счет
  if(accountInfo.MarginMode() != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING) {
    logger.Critical("Only hedge account is avaliable: ACCOUNT_MARGIN_MODE_RETAIL_HEDGING");
    return(INIT_FAILED);
  }

  if(!symbolInfo.Name(Symbol())) {
    logger.Critical(StringFormat("Symbol not found: %s", Symbol()));
    return(INIT_FAILED);
  }  
  
  if ((InpDepthHour*60 <= (InpPattern02S + InpPattern02С)) || (InpDepthHour*60 <= (InpPattern01S + InpPattern01С))) {
    string msg = "Глубина определения паттернов (1.02) должна быть больше суммы времен ожидания возврата в уровень и ожидания сигнала (*.05+*.06)";
    Alert(msg);
    logger.Critical(msg);
    return(INIT_PARAMETERS_INCORRECT);
  }  
  
  tradeInfo.SetExpertMagicNumber(InpMagic);
  tradeInfo.SetMarginMode();
  tradeInfo.SetTypeFillingBySymbol(symbolInfo.Name());
  tradeInfo.SetDeviationInPoints(InpSlippage); 
  tradeInfo.LogLevel(LOG_LEVEL_NO);
  
          ind_handle_pd34 = iCustom(_Symbol, _Period, "PatternDetector34-MT5-Ind", 
                        //"1. НАСТРОЙКИ ПАТТЕРНОВ И УРОВНЕЙ",
                        InpTFPatternDetection, //             = PERIOD_M5;                        // 1.01: Таймферм определения паттернов и уровней 
                        InpDepthHour, //                      = 1*32*24;                          // 1.02: Глубина определения паттернов в прошлое, часов
                        
                        //"2. НАСТРОЙКИ СИГНАЛОВ",
                        InpTFSignalDetection, //              = PERIOD_M1;                        // 2.01: Таймферм определения сигнала по паттерну 
                        
                        //"3. ВЕРХНИЙ УРОВЕНЬ",
                        InpPattern01Active, //                = true;                             // 3.01: Включен
                        InpPattern01BarList, //               = "TH;TOCHL;TOCHL";                 // 3.02: Комбинации цен баров для определения уровня
                        InpPattern01K, //                     = 50;                               // 3.03: Диапазон K, пунктов (макс. отклонение цен баров паттерна)
                        InpPattern01N, //                     = 100;                              // 3.04: Расстояние N, пунктов (мин. от уровня до закр. пробития)
                        InpPattern01S, //                     = 120;                              // 3.05: Макс. время S, мин. (от пробития до возврата в уровень)
                        InpPattern01С, //                     = 5;                                // 3.06: Макс. время C, мин. (от возврата до сигнала)
                        InpPattern01LevelShiftPoint, //       = 0;                                // 3.07: Доп. сдвиг уровня после паттерна, пунктов (0-откл.)
                        InpPattern01ExtremeLevel, //          = false;                            // 3.08: Уровень по экстремуму паттерна (иначе по первому бару)
                        InpPattern01LHLastBarCHitsExtreme, // = true;                             // 3.09: CLOSE пробивающего выше HIGH (если паттерн с HIGH)
                        InpPattern01CheckBTRExtremeFrom, //   = 0;                                // 3.10: Первый № бара паттерна, где LOW д.б. выше прошлого 
                        InpPattern01CheckBTRExtremeTo, //     = 0;                                // 3.11: Последний № бара паттерна, где LOW д.б. выше прошлого 
                        InpPattern01CheckCloseFromBar, //     = 0;                                // 3.12: Начиная с бара проверить закрытие ниже уровня (0-откл)
                        InpPattern01CheckCloseTolerancePnt, //= 0;                                // 3.13: Закрытие ниже уровня допуск (0-откл), пункт
                        InpPattern01MA20Check,                                                    // 3.14: Короткая MA: Проверить положение цены по после возврата
                        InpPattern01MA20Period,                                                   // 3.15: Короткая MA: Период
                        InpPattern01MA20Shift,                                                    // 3.16: Короткая MA: Сдвиг
                        InpPattern01MA20Method,                                                   // 3.17: Короткая MA: Метод
                        InpPattern01MA20AppliedPrice,                                             // 3.18: Короткая MA: Цена
                        InpPattern01MA100Check,                                                   // 3.19: Длинная MA: Проверить направление после возврата
                        InpPattern01MA100Period,                                                  // 3.20: Длинная MA: Период
                        InpPattern01MA100Shift,                                                   // 3.21: Длинная MA: Сдвиг
                        InpPattern01MA100Method,                                                  // 3.22: Длинная MA: Метод
                        InpPattern01MA100AppliedPrice,                                            // 3.23: Длинная MA: Цена
                        InpPattern01ArrowPos,                                                     // 3.24: Момент появления стрелки
                        
                        //"4. НИЖНИЙ УРОВЕНЬ",
                        InpPattern02Active, //                = true;                             // 4.01: Включен
                        InpPattern02BarList, //               = "BL;BOCLH;BOCLH";                 // 4.02: Комбинации цен баров для определения уровня
                        InpPattern02K, //                     = 50;                               // 4.03: Диапазон K, пунктов (макс. отклонение цен баров паттерна)
                        InpPattern02N, //                     = 100;                              // 4.04: Расстояние N, пунктов (мин. от уровня до закр. пробития)
                        InpPattern02S, //                     = 120;                              // 4.05: Макс. время S, мин. (от пробития до возврата в уровень)
                        InpPattern02С, //                     = 5;                                // 4.06: Макс. время C, мин. (от возврата до сигнала)
                        InpPattern02LevelShiftPoint, //       = 0;                                // 4.07: Доп. сдвиг уровня после паттерна, пунктов (0-откл.)
                        InpPattern02ExtremeLevel, //          = false;                            // 4.08: Уровень по экстремуму паттерна (иначе по первому бару)
                        InpPattern02LHLastBarCHitsExtreme, // = true;                             // 4.09: CLOSE пробивающего ниже HIGH (если паттерн с LOW)
                        InpPattern02CheckBTRExtremeFrom, //   = 0;                                // 4.10: Первый № бара паттерна, где HIGH д.б. ниже прошлого 
                        InpPattern02CheckBTRExtremeTo, //     = 0;                                // 4.11: Последний № бара паттерна, где HIGH д.б. ниже прошлого 
                        InpPattern02CheckCloseFromBar, //     = 0;                                // 4.12: Начиная с бара проверить закрытие выше уровня (0-откл) 
                        InpPattern02CheckCloseTolerancePnt, //
                        InpPattern02MA20Check,                                                    // 4.14: Короткая MA: Проверить положение цены по после возврата
                        InpPattern02MA20Period,                                                   // 4.15: Короткая MA: Период
                        InpPattern02MA20Shift,                                                    // 4.16: Короткая MA: Сдвиг
                        InpPattern02MA20Method,                                                   // 4.17: Короткая MA: Метод
                        InpPattern02MA20AppliedPrice,                                             // 4.18: Короткая MA: Цена
                        InpPattern02MA100Check,                                                   // 4.19: Длинная MA: Проверить направление после возврата
                        InpPattern02MA100Period,                                                  // 4.20: Длинная MA: Период
                        InpPattern02MA100Shift,                                                   // 4.21: Длинная MA: Сдвиг
                        InpPattern02MA100Method,                                                  // 4.22: Длинная MA: Метод
                        InpPattern02MA100AppliedPrice,                                            // 4.23: Длинная MA: Цена
                        InpPattern02ArrowPos,                                                     // 4.24: Момент появления стрелки
                        
                        //"5. ФИЛЬТР ПО ВРЕМЕНИ",
                        InpTimeAddHours, //                   = 3;                                // 5.01: Сдвиг времени в часах
                        InpTimeMonday_Not_Arrow, //           = "08:30-08:55,10:30-12:15";        // 5.02: Понедельник не торговые периоды (максимум 20 периодов)
                        InpTimeTuesday_Not_Arrow, //          = "08:30-08:55,10:30-12:15";        // 5.03: Вторник не торговые периоды (максимум 20 периодов)
                        InpTimeWednesday_Not_Arrow,  //       = "08:30-08:55,10:30-12:15";        // 5.04: Среда не торговые периоды (максимум 20 периодов)
                        InpTimeThursday_Not_Arrow, //         = "08:30-08:55,10:30-12:15";        // 5.05: Четверг не торговые периоды (максимум 20 периодов)
                        InpTimeFriday_Not_Arrow, //           = "08:30-08:55,10:30-12:15";        // 5.06: Пятница не торговые периоды (максимум 20 периодов)
                        InpTimeEveryDay_Not_Arrow, //         = "00:00-01:00";                    // 5.07: Не торговые периоды на каждый день (максимум 20 периодов)
                        InpTimeEveryHour_Not_Arrow,  //        = "00-10";                          // 5.08: Не торговые периоды на каждый час (максимум 20 периодов)
                        
                        //"6. ГРАФИКА",
                        InpPatternDraw, //                    = true;                             // 6.01: Рисовать уровни
                        InpPatternDrawNonHit
                        //InpPattern01ArrowCode, //             = 233;                              // 6.02: ВЕРХ: Код символа стрелки
                        //InpPattern02ArrowCode  //             = 234;                              // 6.03: НИЗ: Код символа стрелки
//                        InpPattern01StartCode, //             = 167;                              // 6.04: ВЕРХ: Код символа начала и подтверждения паттерна
//                        InpPattern02StartCode, //             = 167;                              // 6.05: НИЗ: Код символа начала и подтверждения паттерна
//                        InpPattern01Name, //                  = "ВЕРХ";                           // 6.06: ВЕРХ: Подпись линий уровня
//                        InpPattern02Name, //                  = "НИЗ";                            // 6.07: НИЗ: Подпись линий уровня
//                        InpPattern01Color, //                 = clrGreen;                         // 6.08: ВЕРХ: Цвет
//                        InpPattern02Color, //                 = clrRed;                           // 6.09: Цвет символа
//                        
//                        "7. ПРОЧЕЕ",
//                        InpLogLevel //                       = LogLevel(WARN);                  // 7.01: Уровень логирования
                        ); 
                        
  if(ind_handle_pd34 < 0) {
    logger.Critical("PatternDetector23 Indicator load failed");
    return(INIT_FAILED);
  }    
  
  if (CheckPointer(new_bar_detector) == POINTER_INVALID) {
    new_bar_detector = new DKNewBarDetector(symbolInfo.Name());
    new_bar_detector.AddTimeFrame(PERIOD_M1);  
  }  
  
  arrow_up_last_dt = 0;
  arrow_down_last_dt = 0;
  
  up_open_cnt = 0; down_open_cnt = 0;
  up_close_cnt = 0; down_close_cnt = 0;
  
  EventSetTimer(60);
   
  return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)  {
  if (reason != REASON_CHARTCHANGE)
    if (new_bar_detector != NULL) 
      delete new_bar_detector;
  IndicatorRelease(ind_handle_pd34);
  EventKillTimer();
   
  logger.Warn(StringFormat("1. РЕЗУЛЬТАТ РАСЧЕТА В РЕЖИМЕ '%s': СТРЕЛКА ВВЕРХ: WIN_RATE=%d/%d=%0.1f%%",
                           EnumToString(InpCloseMode),
                           up_close_cnt, up_open_cnt, (up_open_cnt != 0) ? (double)up_close_cnt/up_open_cnt*100 : 0)); 
  logger.Warn(StringFormat("2. РЕЗУЛЬТАТ РАСЧЕТА В РЕЖИМЕ '%s': СТРЕЛКА ВНИЗ: WIN_RATE=%d/%d=%0.1f%%",
                           EnumToString(InpCloseMode),
                           down_close_cnt, down_open_cnt, (down_open_cnt != 0) ? (double)down_close_cnt/down_open_cnt*100 : 0)); 
  logger.Warn(StringFormat("3. РЕЗУЛЬТАТ РАСЧЕТА В РЕЖИМЕ '%s': ВСЕ СТРЕЛКИ: FIXED_WIN_RATE=%d/%d=%0.1f%%",
                           EnumToString(InpCloseMode),
                           up_close_cnt+down_close_cnt, 
                           up_open_cnt+down_open_cnt, 
                           ((up_open_cnt+down_open_cnt) != 0) ? (double)(up_close_cnt+down_close_cnt)/(up_open_cnt+down_open_cnt)*100 : 0)); 
  }

 
ulong OpenPosition(const int _dir, const double _level_price) {
  double lot = symbolInfo.NormalizeLot(InpMMValue);
  if(lot <= 0) {
    logger.Error("Open position error with lot<=0");
    return(0);
  }

  string comment = StringFormat("%s|%d|%d|%d|%d|%f", 
                                InpGlobalPrefix, 
                                InpCloseMode,
                                InpFixedCloseAfterMin,
                                InpExpCloseTF,
                                InpExpCloseAddBarWhenLessToCloseMin,
                                _level_price);
  bool openRes;
  if(_dir > 0)
    openRes = tradeInfo.Buy(lot, _Symbol, 0, 0, 0, comment);
  else
    openRes = tradeInfo.Sell(lot, _Symbol, 0, 0, 0, comment);

  uint ret_code = tradeInfo.ResultRetcode();
  ulong ret_deal = tradeInfo.ResultDeal();
  ulong ret_order = tradeInfo.ResultOrder();
  
  logger.Log(StringFormat("Open position: RES=%d; RETCODE=%d; ORDER=%I64u; DEAL=%I64u; DIR=%s; LOT=%f; LEVEL_PRICE=%f",
                          openRes,
                          ret_code,
                          ret_order,
                          ret_deal,
                          (_dir > 0) ? "BUY" : "SELL",
                          lot,
                          _level_price),
              (openRes && ret_code == TRADE_RETCODE_DONE) ? INFO : ERROR);
  
  return (openRes && ret_code == TRADE_RETCODE_DONE) ? ((ret_deal != 0) ? ret_deal : ret_order) : 0;
}

bool IsPositionReadyToClose(CPositionInfo& _pos) {
  datetime dt_close_at = _pos.Time() + InpFixedCloseAfterMin*60;
  if (InpCloseMode == CLOSE_MODE_EXPIRATION){
    int exp_bar_idx_start = iBarShift(_Symbol, InpExpCloseTF, _pos.Time());
    datetime exp_bar_dt_start = iTime(_Symbol, InpExpCloseTF, exp_bar_idx_start);
    
    dt_close_at = exp_bar_dt_start + PeriodSeconds(InpExpCloseTF)*1-1;
    double exp_dist_sec = PeriodSeconds(InpExpCloseTF) - (double)(_pos.Time() - exp_bar_dt_start);
    if (exp_dist_sec <= (InpExpCloseAddBarWhenLessToCloseMin * 60))
      dt_close_at = exp_bar_dt_start + PeriodSeconds(InpExpCloseTF)*2-1;    
  }
  
  return(TimeCurrent() >= dt_close_at);
//  string pos_com = _pos.Comment();
//  StringReplace(pos_com, StringFormat("%s|", InpGlobalPrefix), "");
//  long pos_delay = StringToInteger(pos_com);
//  
//  if (pos_delay > 0)
//    return(TimeCurrent() >= (_pos.Time() + pos_delay*60));
//    
//  return false;
}

// Парсит коммент позы и возвращает цену уровня
double GetPosLevelPriceFromComment(CPositionInfo& _pos) {
  string comment_parts[];
  if (StringSplit(_pos.Comment(), StringGetCharacter("|", 0), comment_parts) >= 0) {
    double level_price = StringToDouble(comment_parts[ArraySize(comment_parts)-1]);
    return level_price;
  }
  
  return 0.0;    
}


// Проверяет прибыльность по правилам рынка бинарных опционов.
// Если текушая цена позы при закрытии лучше цены уровня, то поза прибыльная.
bool IsPosProfitInOptionMarket(CPositionInfo& _pos, const double _level_price) {
  if (_level_price <= 0.0) return false;
  symbolInfo.RefreshRates();
  //double curr_price = _pos.PriceCurrent();
  double curr_price = symbolInfo.Bid();
  if ((_pos.PositionType() == POSITION_TYPE_BUY  && curr_price > _level_price) || 
      (_pos.PositionType() == POSITION_TYPE_SELL && curr_price < _level_price)) 
    return true;
  
  return false;
}

void CloseTrades() {
  int i = 0;
  while (i < PositionsTotal()) {
    if(positionInfo.SelectByIndex(i))
      if (positionInfo.Symbol() == _Symbol 
        && positionInfo.Magic() == InpMagic) {
         
        if (IsPositionReadyToClose(positionInfo))
          if (tradeInfo.PositionClose(positionInfo.Ticket())) {
            uint ret_code = tradeInfo.ResultRetcode();
            if (ret_code == TRADE_RETCODE_DONE) {
              double level_price = GetPosLevelPriceFromComment(positionInfo);
              symbolInfo.RefreshRates();
              double curr_price = symbolInfo.Bid();
              logger.Info(StringFormat("Position closed: TICKET=%I64u; RES=%s; DIR=%s; LEVEL_PRICE=%f %s CLOSE_PRICE=%f", 
                                        positionInfo.Ticket(),
                                        (IsPosProfitInOptionMarket(positionInfo, level_price)) ? "PROFIT" : "LOSS",
                                        (positionInfo.PositionType() == POSITION_TYPE_BUY) ? "BUY" : "SELL",
                                        level_price,
                                        (level_price > curr_price) ? ">" : "<",
                                        curr_price
                                        ));
              if (positionInfo.PositionType() == POSITION_TYPE_BUY  && IsPosProfitInOptionMarket(positionInfo, level_price)) up_close_cnt++;
              if (positionInfo.PositionType() == POSITION_TYPE_SELL && IsPosProfitInOptionMarket(positionInfo, level_price)) down_close_cnt++;
              continue;
            }
            else
              logger.Error(StringFormat("Position close error: TICKET=%I64u | RET_CODE=%d", positionInfo.Ticket(), ret_code));
        } 
      }      
    i++;
  }  
}
  
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()  {
  
  
//  int start_pos = aBarStart;
//  
//  datetime start_date = TimeCurrent();
//  start_date = MathFloor(start_date/86400)*86400 - 86400 * InputZoneDetectionDays;
//  int count = iBarShift(symbolInfo.Name(), InputZoneDetectionTimeFrame, start_date);  


  if (CopyBuffer(ind_handle_pd34, 2, 0, 1, arrow_up_buffer) >= 0)
    if (arrow_up_buffer[0] > 0.0) {
      datetime dt = iTime(_Symbol, _Period, 0);
      if (dt > arrow_up_last_dt) {
        logger.Info(StringFormat("Arrow detected: UP | PRICE=%f | DT=%s", arrow_up_buffer[0], TimeToString(dt)));
        if (OpenPosition(+1, arrow_up_buffer[0])) {
          arrow_up_last_dt = dt;
          up_open_cnt++;
        }
      }
    }
    
  if (CopyBuffer(ind_handle_pd34, 3, 0, 1, arrow_down_buffer) >= 0) 
    if (arrow_down_buffer[0] > 0.0) {
      datetime dt = iTime(_Symbol, _Period, 0);
      if (dt > arrow_down_last_dt) {
        logger.Info(StringFormat("Arrow detected: DOWN | PRICE=%f | DT=%s", arrow_down_buffer[0], TimeToString(dt)));
        if (OpenPosition(-1, arrow_down_buffer[0])) {
          arrow_down_last_dt = dt;
          down_open_cnt++;
        }
      }
  }  
  
//  if (new_bar_detector.CheckNewBarAvaliable(PERIOD_M1)) {
    //logger.Debug(StringFormat("New bar detected: TF=%s", EnumToString(PERIOD_M1)));
    CloseTrades();  
//  }
  

  //logger.Info(StringFormat("UP=%f | DOWN=%f", buffer_arrow_up[0], buffer_arrow_down[0]));
  //logger.Info("1");
   
  }
  
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
void OnTrade()
  {
//---
   
  }
//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
//---
   
  }
//+------------------------------------------------------------------+
