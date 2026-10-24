let widgetStorage: LocalStorage = new LocalStorage();

@Entry(widgetStorage)
@Component
struct MusicWidgetCard {
  @LocalStorageProp('title') title: string = '今天想听什么？';
  @LocalStorageProp('subtitle') subtitle: string = '打开清听';
  @LocalStorageProp('status') status: string = '发现好音乐';

  build() {
    Button() {
      Column() {
        Row() {
          Text('♪')
            .fontSize(24)
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Bold)
          Text('清听')
            .fontSize(12)
            .fontColor('#FFE4E6')
            .margin({ left: 6 })
          Blank()
          Text(this.status)
            .fontSize(10)
            .fontColor('#C8424C')
            .backgroundColor('#FFFFFF')
            .borderRadius(9)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Blank()

        Text(this.title)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Text(this.subtitle)
          .fontSize(12)
          .fontColor('#FFE4E6')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 4 })
      }
      .width('100%')
      .height('100%')
      .padding(14)
    }
    .type(ButtonType.Normal)
    .width('100%')
    .height('100%')
    .padding(0)
    .backgroundColor('#C8424C')
    .borderRadius(16)
    .onClick(() => {
      postCardAction(this, {
        action: 'router',
        bundleName: 'com.example.harmonymusicapp',
        moduleName: 'entry',
        abilityName: 'EntryAbility',
        params: { from: 'widget' }
      });
    })
  }
}
