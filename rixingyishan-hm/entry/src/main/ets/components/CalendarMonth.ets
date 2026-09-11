import { Theme } from '../common/Theme';
import { dayKeyOf } from '../common/Utils';

export interface CalendarDay {
  day: number;
  dateKey: string;
  isCurrentMonth: boolean;
  isToday: boolean;
  hasRecords: boolean;
}

const WEEKDAYS: string[] = ['日', '一', '二', '三', '四', '五', '六'];

/**
 * CalendarMonth — 月历（打点 + 选中 + 前后翻月）
 */
@Component
export struct CalendarMonth {
  @Prop year: number = 0;
  @Prop month: number = 0;
  @Prop selectedDayKey: string = '';
  @Prop dottedDayKeys: string[] = [];
  onSelect: (dayKey: string) => void = (dayKey: string) => {};
  onMonthChange: (year: number, month: number) => void = (year: number, month: number) => {};

  private currentMonthText(): string {
    return `${this.year}年${this.month}月`;
  }

  private buildDays(): CalendarDay[] {
    const firstOfMonth = new Date(this.year, this.month - 1, 1);
    const startOffset = firstOfMonth.getDay();
    const start = new Date(this.year, this.month - 1, 1 - startOffset);
    const todayKey = dayKeyOf(new Date());
    const days: CalendarDay[] = [];
    for (let i = 0; i < 42; i++) {
      const cur = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i);
      const key = dayKeyOf(cur);
      const cell: CalendarDay = {
        day: cur.getDate(),
        dateKey: key,
        isCurrentMonth: cur.getMonth() + 1 === this.month,
        isToday: key === todayKey,
        hasRecords: this.dottedDayKeys.includes(key)
      };
      days.push(cell);
      const lastOfMonth = new Date(this.year, this.month, 0);
      if (cur.getTime() > lastOfMonth.getTime() && cur.getDay() === 0) {
        break;
      }
    }
    return days;
  }

  build() {
    Column() {
      Row() {
        Text(this.currentMonthText())
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
        Blank()
        Text('◀')
          .fontSize(14)
          .fontColor('#666666')
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .onClick(() => {
            let y = this.year;
            let m = this.month - 1;
            if (m < 1) {
              m = 12;
              y -= 1;
            }
            this.onMonthChange(y, m);
          })
        Text('▶')
          .fontSize(14)
          .fontColor('#666666')
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .onClick(() => {
            let y = this.year;
            let m = this.month + 1;
            if (m > 12) {
              m = 1;
              y += 1;
            }
            this.onMonthChange(y, m);
          })
      }
      .width('100%')
      .margin({ bottom: 12 })

      Row() {
        ForEach(WEEKDAYS, (w: string) => {
          Text(w)
            .fontSize(12)
            .fontColor('#999999')
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
        })
      }
      .width('100%')
      .margin({ bottom: 6 })

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.buildDays(), (d: CalendarDay) => {
          Column() {
            Text(`${d.day}`)
              .fontSize(14)
              .fontColor(!d.isCurrentMonth ? '#CCCCCC' : (d.dateKey === this.selectedDayKey ? Color.White : (d.isToday ? Theme.accent : '#333333')))
              .fontWeight(d.isToday && d.dateKey !== this.selectedDayKey ? FontWeight.Bold : FontWeight.Normal)
            if (d.hasRecords) {
              Circle({ width: 4, height: 4 })
                .fill(d.dateKey === this.selectedDayKey ? Color.White : Theme.accent)
                .margin({ top: 2 })
            } else {
              Column()
                .height(6)
            }
          }
          .width('14.28%')
          .height(44)
          .justifyContent(FlexAlign.Center)
          .borderRadius(6)
          .backgroundColor(d.dateKey === this.selectedDayKey ? Theme.accent : Color.Transparent)
          .onClick(() => {
            this.onSelect(d.dateKey);
          })
        }, (d: CalendarDay) => d.dateKey)
      }
      .width('100%')
    }
    .width('100%')
    .padding(14)
    .backgroundColor(Color.White)
    .borderRadius(12)
  }
}
