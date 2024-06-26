//+------------------------------------------------------------------+
//|                         PatternDetector34-MT5-WinRate-Script.mq5 |
//|                                                  Denis Kislitsyn |
//|                                             https://kislitsyn.me |
//+------------------------------------------------------------------+
#property copyright "Denis Kislitsyn"
#property link      "https://kislitsyn.me"
#property version   "1.0.2"



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

#property script_show_inputs

//input  group              "0. ТОРГОВЛЯ"
//input  ENUM_MM_TYPE       InpMMType                         = ENUM_MM_TYPE_FIXED_LOT;         // 0.01: Тип MM
       //double             InpMMValue                          = 1.0;                              // 0.01: Лот
       //uint               InpTradeDelayMin                    = 10;                               // 0.02: Время в сделке, мин
       //ulong              InpSlippage                         = 2;                                // 0.03: Макс. проскальзование операций, пунктов

input  group              "1. ПЕРИОД"
input  datetime           InpStart                            = D'2024.01.01';                             // 1.01: Начало периода
input  datetime           InpFinish                           = D'2024.04.01';                             // 1.02: Конец периода
input  uint               InpFixedCloseAfterMin               = 5;                              // 1.02: Время фиксированного закрытия после стрелки, мин
input  uint               InpExpCloseAddBarWhenLessToCloseMin = 3;                              // 1.03: Мин.время от стрелки до конца бара для экспирации, мин

//input  group              "1. НАСТРОЙКИ ПАТТЕРНОВ И УРОВНЕЙ"
       ENUM_TIMEFRAMES    InpTFPatternDetection             = PERIOD_M5;                        // 1.01: Таймферм определения паттернов и уровней 
       ulong              InpDepthHour                      = 1500;                                // 1.02: Глубина определения паттернов в прошлое, часов

input  group              "2. НАСТРОЙКИ СИГНАЛОВ"
       ENUM_TIMEFRAMES    InpTFSignalDetection              = PERIOD_M1;                        // 2.01: Таймферм определения сигнала по паттерну 

input  int                InpMAShortPeriod                  = 20;                               // 2.02: Фильтр 1. Короткая MA: Период
input  int                InpMAShortShift                   = 0;                                // 2.03: Фильтр 1. Короткая MA: Сдвиг
input  ENUM_MA_METHOD     InpMAShortMethod                  = MODE_SMA;                         // 2.04: Фильтр 1. Короткая MA: Метод
input  ENUM_APPLIED_PRICE InpMAShortAppliedPrice            = PRICE_CLOSE;                      // 2.05: Фильтр 1. Короткая MA: Цена

input  int                InpMALongPeriod                   = 100;                              // 2.05: Фильтр 2. Длинная MA: Период
input  int                InpMALongShift                    = 0;                                // 2.06: Фильтр 2. Длинная MA: Сдвиг
input  ENUM_MA_METHOD     InpMALongMethod                   = MODE_SMA;                         // 2.07: Фильтр 2. Длинная MA: Метод
input  ENUM_APPLIED_PRICE InpMALongAppliedPrice             = PRICE_CLOSE;                      // 2.08: Фильтр 2. Длинная MA: Цена

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
input  bool               InpPattern01CheckMA20             = true;                             // 3.14: Проверить положение цены по Короткой MA после возврата
input  bool               InpPattern01CheckMA100            = true;                             // 3.15: Проверить направление Длиной MA после возврата
input  ENUM_ARROW_POS     InpPattern01ArrowPos              = ARROW_POS_CONFIRM;                // 3.16: Момент появления стрелки

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
input  bool               InpPattern02CheckMA20             = true;                             // 4.15: Проверить положение цены по Короткой MA после возврата
input  bool               InpPattern02CheckMA100            = true;                             // 4.16: Проверить направление Длиной MA после возврата
input  ENUM_ARROW_POS     InpPattern02ArrowPos              = ARROW_POS_CONFIRM;                // 4.17: Момент появления стрелки

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
sinput bool               InpPatternDraw                    = false;                            // 6.01: Рисовать уровни
sinput uint               InpPattern01ArrowCode             = 233;                              // 6.02: ВЕРХ: Код символа стрелки
sinput uint               InpPattern02ArrowCode             = 234;                              // 6.03: НИЗ: Код символа стрелки
sinput uint               InpPattern01StartCode             = 167;                              // 6.04: ВЕРХ: Код символа начала и подтверждения паттерна
sinput uint               InpPattern02StartCode             = 167;                              // 6.05: НИЗ: Код символа начала и подтверждения паттерна
sinput string             InpPattern01Name                  = "ВЕРХ";                           // 6.06: ВЕРХ: Подпись линий уровня
sinput string             InpPattern02Name                  = "НИЗ";                            // 6.07: НИЗ: Подпись линий уровня
sinput color              InpPattern01Color                 = clrGreen;                         // 6.08: ВЕРХ: Цвет
sinput color              InpPattern02Color                 = clrRed;                           // 6.09: НИЗ: Цвет

input  group              "7. ПРОЧЕЕ"
sinput LogLevel           InpLogLevel                       = LogLevel(DEBUG);                  // 7.01: Уровень логирования
//sinput int                InpMagic                          = 20240416;                         // 7.02: Magic
       string             InpGlobalPrefix                   = "PD34S";  

DKLogger logger;

int ind_handle_pd34;

int CountPossitive(double& _arr[]) {
  int res = 0;
  for (int i=0; i<ArraySize(_arr); i++)
    if (_arr[i] > 0) 
      res++;
      
  return res;
}

bool IsChartHistoryLoaded(datetime& _from, datetime& _to) {
  datetime dt_first_bar = iTime(_Symbol, PERIOD_M1, Bars(_Symbol, PERIOD_M1));
  if (dt_first_bar > _from) {
    _from = dt_first_bar;
    return false;  
  }
  
  _from = dt_first_bar;    
  return true;
}

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart() {
  logger.Name = InpGlobalPrefix;
  logger.Level = InpLogLevel;
  logger.Format = "%name%:[%level%] %message%";
  if(MQL5InfoInteger(MQL5_DEBUGGING)) logger.Level = LogLevel(DEBUG);
  
  //string expar = (string)InputMagic;
  //datetime expiration = StringToTime(expar);
  //if (TimeCurrent() > StringToTime((string)InputMagic) + 32 * 24 * 60 * 60) {
  //  MessageBox("Developer version is expired", "Error", MB_OK | MB_ICONERROR);
  //  return(INIT_FAILED);
  //}
  
  if (Period() != PERIOD_M1) {
    logger.Critical("Запустите расчет на M1");
    return;;
  }
  //datetime dt_start = StringToTime("2024.01.01");
  //datetime dt_finish = StringToTime("2024.04.01");
  
  datetime dt_start = InpStart;
  datetime dt_finish = InpFinish;
  datetime dt_now = TimeCurrent();
  InpDepthHour = (dt_now - dt_start);  
  InpDepthHour = InpDepthHour/60/60+1;
  
  logger.Info(StringFormat("СТАРТ РАСЧЕТА [%s;%s] с глубиной индикатора %d часов", 
                          TimeToString(dt_start, TIME_DATE), TimeToString(dt_finish, TIME_DATE),InpDepthHour));      
                          
  Comment("Провряю наличиие истории на графике за выбранный период");
  datetime dt_history_start = dt_start;
  datetime dt_history_finish = dt_now;  
  if (!IsChartHistoryLoaded(dt_history_start, dt_history_finish)) {
    string msg = StringFormat("Для %s/%s данные начинаются с %s. Загрузите недостающую историю, прокрутив график влево.",
                              _Symbol, EnumToString(_Period), 
                              TimeToString(dt_history_start));
    logger.Error(msg);
    Alert(msg);
    Comment("");
    return;
  }
  
  Comment("Инициализирую PatternDetector34-MT5-Ind");
  ind_handle_pd34 = iCustom(_Symbol, _Period, "PatternDetector34-MT5-Ind", 
                        "1. НАСТРОЙКИ ПАТТЕРНОВ И УРОВНЕЙ",
                        InpTFPatternDetection, //             = PERIOD_M5;                        // 1.01: Таймферм определения паттернов и уровней 
                        InpDepthHour, //                      = 1*32*24;                          // 1.02: Глубина определения паттернов в прошлое, часов
                        
                        "2. НАСТРОЙКИ СИГНАЛОВ",
                        InpTFSignalDetection, //              = PERIOD_M1;                        // 2.01: Таймферм определения сигнала по паттерну 
                        
                        InpMAShortPeriod, //                  = 20;                               // 2.01: Фильтр 1. Короткая MA: Период
                        InpMAShortShift, //                   = 0;                                // 2.02: Фильтр 1. Короткая MA: Сдвиг
                        InpMAShortMethod, //                  = MODE_SMA;                         // 2.03: Фильтр 1. Короткая MA: Метод
                        InpMAShortAppliedPrice, //            = PRICE_CLOSE;                      // 2.04: Фильтр 1. Короткая MA: Цена

                        InpMALongPeriod, //                   = 100;                              // 2.05: Фильтр 2. Длинная MA: Период
                        InpMALongShift, //                    = 0;                                // 2.06: Фильтр 2. Длинная MA: Сдвиг
                        InpMALongMethod, //                   = MODE_SMA;                         // 2.07: Фильтр 2. Длинная MA: Метод
                        InpMALongAppliedPrice, //             = PRICE_CLOSE;                      // 2.08: Фильтр 2. Длинная MA: Цена
                        
                        "3. ВЕРХНИЙ УРОВЕНЬ",
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
                        InpPattern01CheckMA20, //             = true;                             // 3.14: Проверить положение цены по Короткой MA после возврата
                        InpPattern01CheckMA100, //            = true;                             // 3.15: Проверить направление Длиной MA после возврата
                        InpPattern01ArrowPos, //              = ARROW_POS_CONFIRM;                // 3.16: Момент появления стрелки
                        
                        "4. НИЖНИЙ УРОВЕНЬ",
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
                        InpPattern02CheckMA20, //             = true;                             // 4.13: Проверить положение цены по Короткой MA после возврата
                        InpPattern02CheckMA100, //            = true;                             // 4.14: Проверить направление Длиной MA после возврата
                        InpPattern02ArrowPos, //              = ARROW_POS_CONFIRM;                // 4.15: Момент появления стрелки
                        
                        "5. ФИЛЬТР ПО ВРЕМЕНИ",
                        InpTimeAddHours, //                   = 3;                                // 5.01: Сдвиг времени в часах
                        InpTimeMonday_Not_Arrow, //           = "08:30-08:55,10:30-12:15";        // 5.02: Понедельник не торговые периоды (максимум 20 периодов)
                        InpTimeTuesday_Not_Arrow, //          = "08:30-08:55,10:30-12:15";        // 5.03: Вторник не торговые периоды (максимум 20 периодов)
                        InpTimeWednesday_Not_Arrow,  //       = "08:30-08:55,10:30-12:15";        // 5.04: Среда не торговые периоды (максимум 20 периодов)
                        InpTimeThursday_Not_Arrow, //         = "08:30-08:55,10:30-12:15";        // 5.05: Четверг не торговые периоды (максимум 20 периодов)
                        InpTimeFriday_Not_Arrow, //           = "08:30-08:55,10:30-12:15";        // 5.06: Пятница не торговые периоды (максимум 20 периодов)
                        InpTimeEveryDay_Not_Arrow, //         = "00:00-01:00";                    // 5.07: Не торговые периоды на каждый день (максимум 20 периодов)
                        InpTimeEveryHour_Not_Arrow, //        = "00-10";                          // 5.08: Не торговые периоды на каждый час (максимум 20 периодов)
                        
                        "6. ГРАФИКА",
                        InpPatternDraw, //                    = true;                             // 6.01: Рисовать уровни
                        InpPattern01ArrowCode, //             = 233;                              // 6.02: ВЕРХ: Код символа стрелки
                        InpPattern02ArrowCode  //             = 234;                              // 6.03: НИЗ: Код символа стрелки
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
    logger.Critical("PatternDetector34 Indicator load failed");
    return;
  }    
   
  Comment("Жду загрузку данных от индикатора PatternDetector34");
  while (!BarsCalculated(ind_handle_pd34)) {    
    Comment("Жду загрузку данных от индикатора PatternDetector34");
    Sleep(500);
  }
  Comment("Получаю буферы индикатора");
  
  double arrow_up_buffer[];
  double arrow_down_buffer[];   
    

      
  // Определяем соответствующие индексы баров для начальной и конечной дат
  int startBar = iBarShift(Symbol(), Period(), dt_start);
  int endBar = iBarShift(Symbol(), Period(), dt_finish);
  
  ArraySetAsSeries(arrow_up_buffer, true); 
  ArraySetAsSeries(arrow_down_buffer, true); 
  
  // Копируем данные индикатора между двумя датами
  ResetLastError();
  int buf_up_res = CopyBuffer(ind_handle_pd34, 2, endBar, startBar - endBar + 1, arrow_up_buffer);  
  int buf_down_res = CopyBuffer(ind_handle_pd34, 3, endBar, startBar - endBar + 1, arrow_down_buffer);  
  int err_code = GetLastError();
  logger.Info(StringFormat("BUF_UP=%d/%d | BUF_DOWN=%d/%d | ERR=%d", 
                           CountPossitive(arrow_up_buffer), buf_up_res, 
                           CountPossitive(arrow_down_buffer), buf_down_res,
                           err_code));
                           
  if (err_code != 0) {
    string msg = StringFormat("Ошибка %d получения буферов из индикатора. Попробуйте уменьшить период.", err_code);
    logger.Critical(msg);
    Alert(msg);
    return;
  }                           
 
  Comment("Расcчитываю WINRATE");
  
  int arrow_cnt_up = 0;
  int winrate_cnt_fixed_up = 0;
  int winrate_cnt_expiration_up = 0;
  
  int arrow_cnt_down = 0;
  int winrate_cnt_fixed_down = 0;
  int winrate_cnt_expiration_down = 0;
  
  CalcWinRate(arrow_up_buffer, +1, endBar, arrow_cnt_up, winrate_cnt_fixed_up, winrate_cnt_expiration_up);
  CalcWinRate(arrow_down_buffer, -1, endBar, arrow_cnt_down, winrate_cnt_fixed_down, winrate_cnt_expiration_down);

  int arrow_cnt = arrow_cnt_up + arrow_cnt_down;
  int winrate_cnt_fixed = winrate_cnt_fixed_up + winrate_cnt_fixed_down;
  int winrate_cnt_expiration = winrate_cnt_expiration_up + winrate_cnt_expiration_down;

  double winrate_fixed_perc_up = (arrow_cnt_up != 0) ? ((double)winrate_cnt_fixed_up / (double)arrow_cnt_up * 100) : 0;
  double winrate_exp_perc_up = (arrow_cnt_up != 0) ? ((double)winrate_cnt_expiration_up / (double)arrow_cnt_up * 100) : 0;
  
  double winrate_fixed_perc_down = (arrow_cnt_down != 0) ? ((double)winrate_cnt_fixed_down / (double)arrow_cnt_down * 100) : 0;
  double winrate_exp_perc_down = (arrow_cnt_down != 0) ? ((double)winrate_cnt_expiration_down / (double)arrow_cnt_down * 100) : 0;

  double winrate_fixed_perc = (arrow_cnt != 0) ? ((double)winrate_cnt_fixed / (double)arrow_cnt * 100) : 0;
  double winrate_exp_perc = (arrow_cnt != 0) ? ((double)winrate_cnt_expiration / (double)arrow_cnt * 100) : 0;
  
  logger.Info(StringFormat("1. РЕЗУЛЬТАТ РАСЧЕТА: СТРЕЛКА ВВЕРХ: FIXED_WIN_RATE=%d/%d=%0.1f%% | EXP_WIN_RATE=%d/%d=%0.1f%%",
                           winrate_cnt_fixed_up, arrow_cnt_up, winrate_fixed_perc_up,
                           winrate_cnt_expiration_up, arrow_cnt_up, winrate_exp_perc_up)); 
  logger.Info(StringFormat("2. РЕЗУЛЬТАТ РАСЧЕТА: СТРЕЛКА ВНИЗ: FIXED_WIN_RATE=%d/%d=%0.1f%% | EXP_WIN_RATE=%d/%d=%0.1f%%",
                           winrate_cnt_fixed_down, arrow_cnt_down, winrate_fixed_perc_down,
                           winrate_cnt_expiration_down, arrow_cnt_down, winrate_exp_perc_down)); 
  logger.Info(StringFormat("3. РЕЗУЛЬТАТ РАСЧЕТА: ВСЕ СТРЕЛКИ: FIXED_WIN_RATE=%d/%d=%0.1f%% | EXP_WIN_RATE=%d/%d=%0.1f%%",
                           winrate_cnt_fixed, arrow_cnt, winrate_fixed_perc,
                           winrate_cnt_expiration, arrow_cnt, winrate_exp_perc));                                                       
  Comment("");
  IndicatorRelease(ind_handle_pd34);
}

void CalcWinRate(double& _buffer[], const int _dir, const int _end_bar,
                 int& _arrow_cnt, int& _winrate_cnt_fixed, int& _winrate_cnt_expiration) {

  string dir_str = (_dir > 0) ? "СТРЕЛКА ВВЕРХ" : "СТРЕЛКА ВНИЗ";
         
  for(int i=0; i<ArraySize(_buffer); i++) {
    if (_buffer[i] != 0) {
      _arrow_cnt++;
      
      datetime dt_arrow = iTime(Symbol(), Period(), _end_bar+i);
      
      datetime dt_close_fixed = iTime(Symbol(), Period(), _end_bar+i-InpFixedCloseAfterMin+1);
      double price_close_fixed = iClose(Symbol(), Period(), _end_bar+i-InpFixedCloseAfterMin+1);

      int exp_bar_idx_start = iBarShift(Symbol(), InpTFPatternDetection, dt_arrow);
      datetime exp_bar_dt_start = iTime(Symbol(), InpTFPatternDetection, exp_bar_idx_start);
      
      datetime exp_bar_dt_finish = exp_bar_dt_start + PeriodSeconds(InpTFPatternDetection)*1-1;
      double exp_dist_sec = PeriodSeconds(InpTFPatternDetection) - (dt_arrow - exp_bar_dt_start);
      if (exp_dist_sec <= (InpExpCloseAddBarWhenLessToCloseMin * 60))
        exp_bar_dt_finish = exp_bar_dt_start + PeriodSeconds(InpTFPatternDetection)*2-1;
        
      double price_close_expiration = iClose(Symbol(), Period(), iBarShift(Symbol(), Period(), exp_bar_dt_finish));

      bool res_fixed = false;
      if (_dir > 0 && price_close_fixed > _buffer[i]) res_fixed = true;
      if (_dir < 0 && price_close_fixed < _buffer[i]) res_fixed = true;
      if (res_fixed) _winrate_cnt_fixed++;
      
      bool res_exp = false;
      if (_dir > 0 && price_close_expiration > _buffer[i]) 
        res_exp = true;
      if (_dir < 0 && price_close_expiration < _buffer[i]) 
        res_exp = true;
      if (res_exp) _winrate_cnt_expiration++;
      
      logger.Debug(StringFormat("%s: ENTRY_BAR=%s; ENTRY_PRICE=%f | FIXED_RES=%s; FIXED_EXIT_BAR=%s; FIXED_CLOSE_PRICE=%f | EXP_RES=%s; EXP_EXIT_BAR=%s; EXP_CLOSE_PRICE=%f", 
                               dir_str,
                               TimeToString(dt_arrow), _buffer[i],
                               (res_fixed) ? "WIN " : "LOSS", TimeToString(dt_close_fixed), price_close_fixed,
                               (res_exp) ? "WIN " : "LOSS", TimeToString(exp_bar_dt_finish), price_close_expiration));
    }
  } 
}
