import SwiftUI

struct HandbookView: View {
    @EnvironmentObject var app: AppModel

    private let audioCodes = ["A2DP", "HFP", "LE Audio"]
    private let controlCodes = ["AVRCP", "HSP", "SPP", "BLE GATT"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    introCard
                    SectionHeader(text: "三条音频通路")
                    ForEach(BluetoothProtocolCatalog.profiles.filter { audioCodes.contains($0.code) }) { profile in
                        profileCard(profile)
                    }
                    SectionHeader(text: "控制 / 遥控通道")
                    ForEach(BluetoothProtocolCatalog.profiles.filter { controlCodes.contains($0.code) }) { profile in
                        profileCard(profile)
                    }
                    codecCard
                    limitsCard
                    howToCard
                }
                .padding(16)
                .padding(.bottom, 24)
                .id(SmokeScroll.anchorID)
            }
            .pageBackground()
            .navigationTitle("协议百科")
            .navigationBarTitleDisplayMode(.inline)
            .followSmokeScrollTick(app.scrollToBottomTick)
        }
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "book.closed.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.accent)
                Text("蓝牙耳机不只有「一个蓝牙」")
                    .font(.headline)
            }
            Text("同一副耳机同时跑好几套协议：一条传音乐，一条管麦克风，还有控制、电量、固件升级。"
                + "「当前链路」看到的是系统正在用的音频协议；「附近设备」看到的是 BLE 上的控制与能力信息。")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText)
                .lineSpacing(2)
        }
        .card()
    }

    private func profileCard(_ profile: ProtocolProfile) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 8) {
                Image(systemName: profile.icon)
                    .font(.subheadline)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(profile.code) · \(profile.name)")
                        .font(.subheadline.weight(.semibold))
                    Text(profile.englishName)
                        .font(.caption2)
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                Spacer(minLength: 4)
                Badge(text: profile.layer.components(separatedBy: " · ").first ?? profile.layer,
                      color: Theme.indigo)
            }
            InfoRow(title: "用途", value: profile.usage, titleWidth: 40)
            InfoRow(title: "编码", value: profile.codec, titleWidth: 40)
            Text(profile.detail)
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
                .lineSpacing(2)
        }
        .card()
    }

    private var codecCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("常见音频编解码").font(.headline)
            Text("协议只是「管道」，真正决定音质的是管道里用的压缩算法。")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)

            codecRow("SBC", "A2DP 的强制底线，所有耳机都支持；码率约 200–345 kbps，听感一般。")
            codecRow("AAC", "Apple 主推。iPhone 与多数耳机协商 AAC（约 250 kbps），音质明显好于 SBC。")
            codecRow("aptX / aptX HD", "高通方案，安卓常用；码率 352 / 576 kbps。iPhone 不支持。")
            codecRow("LDAC", "索尼方案，最高 990 kbps，接近无损；iPhone 不支持。")
            codecRow("LC3", "LE Audio 的强制编解码，同码率下音质优于 SBC，延迟和功耗也更低。")
        }
        .card()
    }

    private func codecRow(_ name: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(name)
                .font(.caption.weight(.semibold))
            Text(detail)
                .font(.caption2)
                .foregroundStyle(Theme.secondaryText)
                .lineSpacing(1.5)
        }
        .padding(.vertical, 2)
    }

    private var limitsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.shield")
                    .font(.subheadline)
                    .foregroundStyle(Theme.orange)
                Text("iOS 的三条硬限制").font(.headline)
            }
            limitRow("1", "系统不向 App 公开 A2DP 的编解码协商结果。本 App 只能从端口类型判断走的是 A2DP、HFP 还是 LE Audio；"
                      + "具体是 AAC 还是 SBC，只能按 iPhone 的默认策略推断。")
            limitRow("2", "CoreBluetooth 只看得见 BLE。只用经典蓝牙的耳机不会出现在扫描列表里，"
                      + "但它的 A2DP/HFP 链路仍会被「当前链路」抓到。")
            limitRow("3", "部分耳机把 GATT 会话交给系统独占，第三方 App 连接后读到的服务可能不全，"
                      + "LE Audio 能力可能因此漏判。")
        }
        .card()
    }

    private func limitRow(_ index: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(index)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Theme.orange)
                .clipShape(Circle())
            Text(text)
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
                .lineSpacing(2)
        }
    }

    private var howToCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("怎么用").font(.headline)
            stepRow("1", "连上耳机，打开「当前链路」，看它正在用哪条音频协议。")
            stepRow("2", "打开「附近设备」，找你的耳机，点进去看 GATT 服务。")
            stepRow("3", "出现 PACS(0x1850) / ASCS(0x184E) 就是 LE Audio；只有 180F / 180A 说明 BLE 只管电量和身份。")
            stepRow("4", "Apple 耳机还能直接读出型号、左右耳与充电盒电量。")
        }
        .card()
    }

    private func stepRow(_ index: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(index)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Theme.accent)
                .frame(width: 18, height: 18)
                .background(Theme.accent.opacity(0.14))
                .clipShape(Circle())
            Text(text)
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
                .lineSpacing(2)
        }
    }
}
