# PatternDetector34-MT5-WinRate-Script

Скрипт рассчитывает WinRate (WR) по количеству сделок, закрывшихся с прибылью:
1. Через фиксированное время после стрелки.
2. Через время экспирации, которое определяется как время закрытия M5 той же свечи, где найдена стрелка, если да ее закрытия осталось больше чем 3 минуты (задается в параметрах), или как время закрытия следующий M5 свечи в противном случае.

### Как запустить

1. Установите скрипт в терминал MT5, скопировав его в каталог данных в папку `Scripts`.
2. Откройте график символа, для которого нужно посчитать WR.
3. Выберите таймфрейм M1.
4. Перетащите скрипт на график.
5. Задайте необходимые настройки:
    - Начало и конец периода. 
    **ВНИМАНИЕ:** Большие периоды могут рассчитываться долго, поэтому начните с небольших, чтобы понять сколько времени занимает расчет на вашем компьютере.
    - Время фиксированного закрытия после стрелки, мин.
    - Мин. время от стрелки до конца бара для экспирации, мин.
    - Все необходимые настройки индикатора для расчета WR.
    - При уровень логирования `INFO` скрипт выведет только результаты расчета WR. 
    - При уровне `DEBUG` скрипт выведет найденную каждую стрелку, ее время, бар закрытия через фиксированное время, бар закрытия экспирации и цены закрытия.

### Результаты

![alt text](img/001.%20Script%20Result.png)