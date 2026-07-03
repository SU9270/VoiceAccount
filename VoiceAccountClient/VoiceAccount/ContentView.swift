//
//  ContentView.swift
//  VoiceAccount
//
//  Created by 苏先森 on 2026/5/30.
//

import SwiftUI
import UIKit
import SwiftData
import AVFoundation
import Combine

struct ContentView: View {
    @State private var recordsState: [ExpenseRecord]
    @State private var categoriesState: [CategoryItem]

    private var allRecords: [ExpenseRecord] {
        recordsState.sorted { $0.date > $1.date }
    }

    private var monthlyTotal: Double {
        allRecords
            .filter { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month) }
            .reduce(0) { $0 + $1.amountValue }
    }

    init() {
        _recordsState = State(initialValue: LocalStore.loadRecords())
        _categoriesState = State(initialValue: LocalStore.loadCategories())
    }

    var body: some View {
        TabView {
            AccountView(
                records: $recordsState,
                monthlyTotal: monthlyTotal,
                categories: categoriesState
            )
                .tabItem {
                    Label("记账", systemImage: "receipt")
                }

            StatsView(
                records: allRecords,
                monthlyTotal: monthlyTotal
            )
                .tabItem {
                    Label("统计", systemImage: "chart.bar")
                }

            HistoryView(
                records: $recordsState
            )
                .tabItem {
                    Label("历史", systemImage: "clock.arrow.circlepath")
                }

            SettingsView(categories: $categoriesState, records: $recordsState)
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
        }
        .tint(AppColors.blue)
        .preferredColorScheme(.dark)
        .onChange(of: recordsState) { _, newValue in
            LocalStore.saveRecords(newValue)
        }
        .onChange(of: categoriesState) { _, newValue in
            LocalStore.saveCategories(newValue)
        }
    }
}

private enum AppColors {
    static let greenHex = "#22C55E"
    static let blueHex = "#60A5FA"
    static let orangeHex = "#FB923C"
    static let redHex = "#F87171"
    static let purpleHex = "#A78BFA"
    static let tealHex = "#2DD4BF"
    static let slateHex = "#475569"
    static let pinkHex = "#EC4899"

    static let background = Color(red: 0.027, green: 0.039, blue: 0.071)
    static let backgroundBottom = Color(red: 0.02, green: 0.027, blue: 0.043)
    static let panel = Color(red: 0.067, green: 0.094, blue: 0.153)
    static let panelSoft = Color.white.opacity(0.06)
    static let line = Color.white.opacity(0.10)
    static let text = Color(red: 0.973, green: 0.98, blue: 0.988)
    static let muted = Color(red: 0.612, green: 0.639, blue: 0.686)
    static let green = Color(hex: greenHex)
    static let blue = Color(hex: blueHex)
    static let orange = Color(hex: orangeHex)
    static let red = Color(hex: redHex)
    static let purple = Color(hex: purpleHex)
    static let teal = Color(hex: tealHex)
    static let slate = Color(hex: slateHex)
}

private struct ExpenseRecord: Identifiable, Codable, Equatable {
    var id = UUID()
    let title: String
    let date: Date
    let category: String
    let amount: String
    let amountValue: Double
    let icon: String
    let colorHex: String

    var time: String {
        Self.timeFormatter.string(from: date)
    }

    var color: Color {
        Color(hex: colorHex)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

private struct CategoryItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var icon: String
    var colorHex: String

    var color: Color {
        Color(hex: colorHex)
    }
}

private let defaultCategories = [
    CategoryItem(name: "餐饮", icon: "fork.knife", colorHex: AppColors.orangeHex),
    CategoryItem(name: "交通", icon: "car.fill", colorHex: AppColors.tealHex),
    CategoryItem(name: "购物", icon: "bag.fill", colorHex: AppColors.purpleHex),
    CategoryItem(name: "居家", icon: "house.fill", colorHex: AppColors.blueHex),
    CategoryItem(name: "娱乐", icon: "gamecontroller.fill", colorHex: AppColors.pinkHex),
    CategoryItem(name: "学习", icon: "book.fill", colorHex: AppColors.slateHex),
    CategoryItem(name: "医疗", icon: "cross.case.fill", colorHex: AppColors.greenHex),
    CategoryItem(name: "运动", icon: "figure.run", colorHex: AppColors.tealHex),
    CategoryItem(name: "旅行", icon: "airplane", colorHex: AppColors.blueHex),
    CategoryItem(name: "通讯", icon: "phone.fill", colorHex: AppColors.purpleHex),
    CategoryItem(name: "宠物", icon: "pawprint.fill", colorHex: AppColors.orangeHex),
    CategoryItem(name: "其他", icon: "ellipsis.circle.fill", colorHex: AppColors.slateHex)
]

private enum LocalStore {
    private static let recordsKey = "voiceAccount.records"
    private static let categoriesKey = "voiceAccount.categories"

    static func loadRecords() -> [ExpenseRecord] {
        load([ExpenseRecord].self, key: recordsKey) ?? []
    }

    static func saveRecords(_ records: [ExpenseRecord]) {
        save(records, key: recordsKey)
    }

    static func loadCategories() -> [CategoryItem] {
        guard var savedCategories = load([CategoryItem].self, key: categoriesKey) else {
            return defaultCategories
        }

        for category in defaultCategories where !savedCategories.contains(where: { $0.name == category.name }) {
            savedCategories.append(category)
        }
        return savedCategories
    }

    static func saveCategories(_ categories: [CategoryItem]) {
        save(categories, key: categoriesKey)
    }

    static func clearAllData() {
        UserDefaults.standard.removeObject(forKey: recordsKey)
        UserDefaults.standard.removeObject(forKey: categoriesKey)
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return nil
        }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else {
            return
        }
        UserDefaults.standard.set(data, forKey: key)
    }
}

private extension Color {
    init(hex: String) {
        let raw = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: raw).scanHexInt64(&value)
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}

private func formatCurrency(_ value: Double) -> String {
    "¥ " + value.formatted(.number.precision(.fractionLength(2)).grouping(.automatic))
}

private func formatPlainCurrency(_ value: Double) -> String {
    "¥" + value.formatted(.number.precision(.fractionLength(2)).grouping(.automatic))
}

private func formatCompactCurrency(_ value: Double) -> String {
    "¥" + value.formatted(.number.precision(.fractionLength(value.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 2)).grouping(.automatic))
}

private struct AppScreen<Content: View>: View {
    var eyebrow: String? = nil
    let title: String
    let trailingIcon: String
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.043, green: 0.063, blue: 0.125), AppColors.background, AppColors.backgroundBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(AppColors.blue.opacity(0.16))
                    .frame(width: 220, height: 220)
                    .blur(radius: 42)
                    .offset(x: -70, y: -110)
            }
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(AppColors.teal.opacity(0.10))
                    .frame(width: 170, height: 170)
                    .blur(radius: 38)
                    .offset(x: 55, y: 20)
            }
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    HeaderView(eyebrow: eyebrow, title: title, trailingIcon: trailingIcon)
                        .padding(.top, 8)
                        .padding(.bottom, 14)

                    content
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
        }
    }
}

private struct HeaderView: View {
    let eyebrow: String?
    let title: String
    let trailingIcon: String

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                if let eyebrow {
                    Text(eyebrow)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(AppColors.muted)
                }

                Text(title)
                    .font(.system(size: 42, weight: .black))
                    .foregroundStyle(AppColors.text)
            }

            Spacer()

            Image(systemName: trailingIcon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppColors.muted)
        }
    }
}

private struct SummaryCard: View {
    let eyebrow: String
    let amount: String
    var chip: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(eyebrow)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white.opacity(0.78))

                Spacer()

                if let chip {
                    Label(chip, systemImage: "arrow.down.right")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 11)
                        .frame(height: 28)
                        .background(.white.opacity(0.14), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1))
                }
            }

            Text(amount)
                .font(.system(size: 44, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.82)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.067, green: 0.094, blue: 0.153),
                            Color(red: 0.027, green: 0.067, blue: 0.122),
                            Color(red: 0.012, green: 0.027, blue: 0.071)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(alignment: .topLeading) {
                    Circle()
                        .fill(AppColors.teal.opacity(0.46))
                        .frame(width: 190, height: 190)
                        .blur(radius: 44)
                        .offset(x: -70, y: -100)
                }
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(AppColors.blue.opacity(0.46))
                        .frame(width: 170, height: 170)
                        .blur(radius: 42)
                        .offset(x: 52, y: -74)
                }
                .overlay(alignment: .bottomTrailing) {
                    Circle()
                        .fill(Color.pink.opacity(0.22))
                        .frame(width: 150, height: 150)
                        .blur(radius: 40)
                        .offset(x: 38, y: 72)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color(red: 0.49, green: 0.827, blue: 0.988).opacity(0.20), lineWidth: 1)
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.38), radius: 24, x: 0, y: 16)
    }
}

private struct AccountView: View {
    @Binding var records: [ExpenseRecord]
    let monthlyTotal: Double
    let categories: [CategoryItem]
    @State private var showingManualEntry = false
    @State private var showingVoiceInput = false

    private var todayRecords: [ExpenseRecord] {
        records
            .filter { Calendar.current.isDateInToday($0.date) }
            .sorted { $0.date > $1.date }
    }

    private var todayTotal: Double {
        todayRecords.reduce(0) { $0 + $1.amountValue }
    }

    var body: some View {
        AppScreen(title: "记账", trailingIcon: "bell") {
            SummaryCard(
                eyebrow: "本月支出",
                amount: formatCurrency(monthlyTotal)
            )

            HStack(spacing: 12) {
                ActionButton(title: "语音输入", icon: "mic.fill", color: AppColors.green) {
                    showingVoiceInput = true
                }
                ActionButton(title: "手动输入", icon: "plus", color: AppColors.blue) {
                    showingManualEntry = true
                }
            }
            .padding(.top, 14)

            SectionHeader(title: "今日记录", detail: "\(todayRecords.count) 笔 · \(formatPlainCurrency(todayTotal))")
                .padding(.top, 24)

            VStack(spacing: 10) {
                if todayRecords.isEmpty {
                    EmptyStateView(icon: "tray", title: "今天还没有记录", subtitle: "点击手动输入添加第一笔支出")
                }

                ForEach(todayRecords) { record in
                    ExpenseRow(record: record) {
                        delete(record)
                    }
                }
            }
        }
        .sheet(isPresented: $showingManualEntry) {
            ManualEntrySheet(categories: categories) { record in
                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                    records.insert(record, at: 0)
                }
            }
                .presentationDetents([.height(620)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(18)
        }
        .sheet(isPresented: $showingVoiceInput) {
            VoiceInputSheet(categories: categories) { newRecords in
                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                    records.insert(contentsOf: newRecords, at: 0)
                }
            }
                .presentationDetents([.height(620)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(18)
        }
    }

    private func delete(_ record: ExpenseRecord) {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            records.removeAll { $0.id == record.id }
        }
    }

}

private struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(color, in: Circle())

                Text(title)
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(AppColors.text)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 88)
            .background(AppColors.panel.opacity(0.88), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(AppColors.line, lineWidth: 1))
            .shadow(color: .black.opacity(0.24), radius: 16, x: 0, y: 10)
        }
        .buttonStyle(.plain)
    }
}

private struct SectionHeader: View {
    let title: String
    var detail: String? = nil

    var body: some View {
        HStack(alignment: .lastTextBaseline) {
            Text(title)
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(AppColors.text)

            Spacer()

            if let detail {
                Text(detail)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppColors.muted)
            }
        }
        .padding(.bottom, 10)
    }
}

private struct ExpenseRow: View {
    let record: ExpenseRecord
    var onDelete: (() -> Void)? = nil
    @State private var showingDelete = false

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: record.icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(record.color, in: Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text(record.title)
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(AppColors.text)

                    Text("\(record.time) · \(record.category)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.muted)
                }

                Spacer(minLength: 8)

                Text(record.amount)
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(AppColors.red)
            }

            if showingDelete, let onDelete {
                Button(role: .destructive) {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        showingDelete = false
                    }
                    onDelete()
                } label: {
                    Label("删除", systemImage: "trash.fill")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(AppColors.red, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minHeight: 66)
        .background(AppColors.panel.opacity(0.86), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(AppColors.line, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture {
            guard onDelete != nil else { return }
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                showingDelete.toggle()
            }
        }
    }
}

private struct ManualEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    let categories: [CategoryItem]
    let onSave: (ExpenseRecord) -> Void
    @State private var amount = ""
    @State private var title = ""
    @State private var date = Date()
    @State private var selectedCategory = "餐饮"

    var body: some View {
        SheetShell(title: "新增支出", close: { dismiss() }) {
            VStack(spacing: 12) {
                EditableField(label: "金额", text: $amount, prefix: "¥", placeholder: "0.00", keyboard: .decimalPad)
                VStack(alignment: .leading, spacing: 7) {
                    Text("标题")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(AppColors.muted)

                    TextField("输入支出标题", text: $title)
                        .font(.system(size: 19, weight: .heavy))
                        .foregroundStyle(AppColors.text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .frame(height: 34)
                }
                .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                .padding(.horizontal, 15)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.white.opacity(0.13), lineWidth: 1))
                DateField(label: "时间", date: $date)

                VStack(alignment: .leading, spacing: 10) {
                    Text("分类")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(AppColors.text)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                        ForEach(categories) { category in
                            CategoryChoice(
                                title: category.name,
                                icon: category.icon,
                                selected: selectedCategory == category.name
                            ) {
                                selectedCategory = category.name
                            }
                        }
                    }
                }

                PrimaryButton(title: "保存") {
                    guard let value = Double(amount.replacingOccurrences(of: ",", with: "")), value > 0 else {
                        return
                    }
                    let category = categories.first { $0.name == selectedCategory } ?? defaultCategories[0]
                    let record = ExpenseRecord(
                        title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? selectedCategory : title.trimmingCharacters(in: .whitespacesAndNewlines),
                        date: date,
                        category: category.name,
                        amount: "-¥" + value.formatted(.number.precision(.fractionLength(value.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 2))),
                        amountValue: value,
                        icon: category.icon,
                        colorHex: category.colorHex
                    )
                    onSave(record)
                    dismiss()
                }
            }
        }
    }
}

private struct VoiceInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var recorder = VoiceRecorder()
    let categories: [CategoryItem]
    let onSave: ([ExpenseRecord]) -> Void

    var body: some View {
        SheetShell(title: "语音记账", close: { dismiss() }) {
            VStack(spacing: 18) {
                if recorder.parsedDrafts.isEmpty {
                    Spacer(minLength: 14)
                    VoiceHeroView(isRecording: recorder.isRecording, isParsing: recorder.isParsing)
                        .padding(.top, 16)
                }

                VStack(spacing: 10) {
                    Text(recorder.titleText)
                        .font(.system(size: 26, weight: .black))
                        .foregroundStyle(AppColors.text)

                    Text(recorder.statusText)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.muted)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .frame(minHeight: 44)
                }
                .padding(.horizontal, 14)

                if recorder.isParsing {
                    AIParsingView()
                }

                if !recorder.parsedDrafts.isEmpty {
                    ParsedExpenseEditor(drafts: $recorder.parsedDrafts, categories: categories)
                }

                Spacer(minLength: 10)

                if !recorder.parsedDrafts.isEmpty {
                    PrimaryButton(title: "保存 \(recorder.parsedDrafts.count) 条记录") {
                        saveParsedRecords()
                    }
                } else if recorder.canFinishRecording {
                    PrimaryButton(title: recorder.primaryButtonTitle) {
                        recorder.finishRecordingAndParse(categories: categories)
                    }
                    .disabled(recorder.isBusy)
                    .opacity(recorder.isBusy ? 0.62 : 1)
                } else {
                    PrimaryButton(title: "开始录音") {
                        recorder.startRecording()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            recorder.startRecording()
        }
        .onDisappear {
            recorder.cancelIfNeeded()
        }
    }

    private func saveParsedRecords() {
        let records = recorder.parsedDrafts.compactMap { draft -> ExpenseRecord? in
            guard let value = Double(draft.amount.replacingOccurrences(of: ",", with: "")), value > 0 else {
                return nil
            }

            let category = categories.first { $0.name == draft.category } ?? categories.first ?? defaultCategories[0]
            let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return ExpenseRecord(
                title: title.isEmpty ? category.name : title,
                date: draft.date,
                category: category.name,
                amount: "-¥" + value.formatted(.number.precision(.fractionLength(value.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 2))),
                amountValue: value,
                icon: category.icon,
                colorHex: category.colorHex
            )
        }

        guard !records.isEmpty else {
            recorder.statusText = "请至少保留一条有效金额的记录"
            return
        }

        onSave(records)
        dismiss()
    }
}

private struct VoiceHeroView: View {
    let isRecording: Bool
    let isParsing: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill((isParsing ? AppColors.blue : AppColors.green).opacity(0.14))
                .frame(width: 176, height: 176)

            Circle()
                .stroke((isParsing ? AppColors.blue : AppColors.green).opacity(0.28), lineWidth: 10)
                .frame(width: 142, height: 142)

            Circle()
                .stroke((isParsing ? AppColors.blue : AppColors.green).opacity(0.16), lineWidth: 18)
                .frame(width: 116, height: 116)

            Image(systemName: isParsing ? "sparkles" : "mic.fill")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 96, height: 96)
                .background(isParsing ? AppColors.blue : AppColors.green, in: Circle())
                .shadow(color: (isParsing ? AppColors.blue : AppColors.green).opacity(isRecording || isParsing ? 0.55 : 0.22), radius: 28, x: 0, y: 0)
        }
    }
}

private struct AIParsingView: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(AppColors.blue)
                    .frame(width: 9, height: animate ? CGFloat(18 + index * 8) : CGFloat(34 - index * 4))
                    .animation(
                        .easeInOut(duration: 0.62)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.08),
                        value: animate
                    )
            }
        }
        .frame(height: 52)
        .frame(maxWidth: .infinity)
        .background(AppColors.panelSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppColors.line, lineWidth: 1))
        .onAppear {
            animate = true
        }
    }
}

private struct ParsedExpenseEditor: View {
    @Binding var drafts: [VoiceExpenseDraft]
    let categories: [CategoryItem]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach($drafts) { $draft in
                    ParsedExpenseCard(draft: $draft, categories: categories) {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            drafts.removeAll { $0.id == draft.id }
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .frame(maxHeight: 360)
    }
}

private struct ParsedExpenseCard: View {
    @Binding var draft: VoiceExpenseDraft
    let categories: [CategoryItem]
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Label("识别条目", systemImage: "sparkles")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(AppColors.blue)

                Spacer()

                Button(action: onDelete) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppColors.red)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                TextField("金额", text: $draft.amount)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(AppColors.text)
                    .frame(maxWidth: 116)
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                TextField("标题", text: $draft.title)
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(AppColors.text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            HStack(spacing: 8) {
                Menu {
                    ForEach(categories) { category in
                        Button(category.name) {
                            draft.category = category.name
                        }
                    }
                } label: {
                    HStack {
                        let category = categories.first { $0.name == draft.category } ?? categories.first ?? defaultCategories[0]
                        Image(systemName: category.icon)
                        Text(category.name)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(AppColors.text)
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                DatePicker("", selection: $draft.date, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .tint(AppColors.blue)
                    .colorScheme(.dark)
                    .frame(height: 44)
                    .padding(.horizontal, 6)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(12)
        .background(AppColors.panelSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppColors.line, lineWidth: 1))
    }
}

private struct VoiceExpenseDraft: Identifiable, Equatable {
    var id = UUID()
    var amount: String
    var title: String
    var category: String
    var date = Date()
}

@MainActor
private final class VoiceRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var isUploading = false
    @Published var isParsing = false
    @Published var elapsedSeconds = 0
    @Published var statusText = "说出金额、标题和分类，例如：晚餐 86 元 餐饮"
    @Published var parsedDrafts: [VoiceExpenseDraft] = []

    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var timer: Timer?

    var isBusy: Bool {
        isUploading || isParsing
    }

    var canFinishRecording: Bool {
        isRecording || recordingURL != nil || isBusy
    }

    var primaryButtonTitle: String {
        if isUploading {
            return "正在上传..."
        }
        if isParsing {
            return "AI 正在解析..."
        }
        return "完成录音并解析"
    }

    var titleText: String {
        if isUploading {
            return "正在上传"
        }
        if isParsing {
            return "AI 正在解析"
        }
        if !parsedDrafts.isEmpty {
            return "确认记账明细"
        }
        if isRecording {
            return "正在录音 \(Self.durationFormatter.string(from: TimeInterval(elapsedSeconds)) ?? "00:00")"
        }
        if recordingURL != nil {
            return "录音完成"
        }
        return "语音记账"
    }

    func startRecording() {
        guard !isRecording, !isBusy else {
            return
        }

        recordingURL = nil
        parsedDrafts = []
        elapsedSeconds = 0
        statusText = "正在请求麦克风权限..."
        requestMicrophonePermission()
    }

    func finishRecordingAndParse(categories: [CategoryItem]) {
        guard !isBusy else {
            return
        }

        if isRecording {
            recorder?.stop()
            recorder = nil
            isRecording = false
            stopTimer()
        }

        guard let recordingURL else {
            statusText = "没有可上传的录音文件"
            return
        }

        isUploading = true
        statusText = "录音已保存，正在上传..."

        Task {
            do {
                let response = try await AudioUploadService.upload(fileURL: recordingURL)
                self.recordingURL = nil
                isUploading = false
                isParsing = true
                statusText = "录音已上传，正在用 AI 识别金额、标题和分类..."

                let parseResponse = try await AudioParseService.parse(audioURL: response.url, categories: categories)
                parsedDrafts = parseResponse.items.map { item in
                    VoiceExpenseDraft(
                        amount: item.amount.formatted(.number.precision(.fractionLength(item.amount.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 2))),
                        title: item.title,
                        category: categories.contains(where: { $0.name == item.category }) ? item.category : (categories.first?.name ?? "其他"),
                        date: Date()
                    )
                }
                statusText = parsedDrafts.isEmpty ? "AI 没有识别到有效支出，可重新录音" : "请确认并编辑识别结果"
                isParsing = false
            } catch {
                statusText = "处理失败：\(error.localizedDescription)"
                isUploading = false
                isParsing = false
            }
        }
    }

    func cancelIfNeeded() {
        if isRecording {
            recorder?.stop()
            recorder = nil
            isRecording = false
            stopTimer()
        }

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func beginRecording() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)

            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("voice-account-\(UUID().uuidString)")
                .appendingPathExtension("m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.prepareToRecord()
            guard recorder.record() else {
                self.recorder = nil
                recordingURL = nil
                isRecording = false
                statusText = "录音启动失败：没有可用的麦克风输入"
                return
            }

            self.recorder = recorder
            recordingURL = url
            isRecording = true
            statusText = "正在录音，说出金额、标题和分类"
            startTimer()
        } catch {
            statusText = "录音启动失败：\(error.localizedDescription)"
        }
    }

    private func requestMicrophonePermission() {
        let completion: @Sendable (Bool) -> Void = { [weak self] granted in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if granted {
                    self.beginRecording()
                } else {
                    self.statusText = "没有麦克风权限，请在系统设置中允许访问麦克风"
                }
            }
        }

        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission(completionHandler: completion)
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission(completion)
        }
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.elapsedSeconds += 1
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()
}

private struct AudioUploadResponse: Decodable {
    let url: String
    let path: String?
}

private struct AudioParseResponse: Decodable {
    let items: [ParsedExpenseItem]
}

private struct ParsedExpenseItem: Decodable {
    let amount: Double
    let title: String
    let category: String
}

private struct CategoryPayload: Encodable {
    let name: String
    let icon: String
    let colorHex: String
}

private enum AudioUploadService {
    #if targetEnvironment(simulator)
    private static let baseURL = URL(string: "http://127.0.0.1:5000")!
    #else
    private static let baseURL = URL(string: "http://192.168.1.2:5000")!
    #endif
    private static let uploadURL = baseURL.appendingPathComponent("upload-audio")

    static func upload(fileURL: URL) async throws -> AudioUploadResponse {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = try makeBody(fileURL: fileURL, boundary: boundary)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AudioUploadError.connection(uploadURL.absoluteString, error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AudioUploadError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw AudioUploadError.server(message)
        }

        return try JSONDecoder().decode(AudioUploadResponse.self, from: data)
    }

    private static func makeBody(fileURL: URL, boundary: String) throws -> Data {
        var body = Data()
        let filename = fileURL.lastPathComponent
        let audioData = try Data(contentsOf: fileURL)

        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"audio\"; filename=\"\(filename)\"\r\n")
        body.appendString("Content-Type: audio/mp4\r\n\r\n")
        body.append(audioData)
        body.appendString("\r\n")
        body.appendString("--\(boundary)--\r\n")

        return body
    }
}

private enum AudioParseService {
    #if targetEnvironment(simulator)
    private static let baseURL = URL(string: "http://127.0.0.1:5000")!
    #else
    private static let baseURL = URL(string: "http://192.168.1.2:5000")!
    #endif
    private static let parseURL = baseURL.appendingPathComponent("parse-audio-expenses")

    static func parse(audioURL: String, categories: [CategoryItem]) async throws -> AudioParseResponse {
        var request = URLRequest(url: parseURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            ParseRequest(
                audioURL: audioURL,
                categories: categories.map {
                    CategoryPayload(name: $0.name, icon: $0.icon, colorHex: $0.colorHex)
                }
            )
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AudioUploadError.connection(parseURL.absoluteString, error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AudioUploadError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw AudioUploadError.server(message)
        }

        return try JSONDecoder().decode(AudioParseResponse.self, from: data)
    }

    private struct ParseRequest: Encodable {
        let audioURL: String
        let categories: [CategoryPayload]

        enum CodingKeys: String, CodingKey {
            case audioURL = "audio_url"
            case categories
        }
    }
}

private enum AudioUploadError: LocalizedError {
    case invalidResponse
    case server(String)
    case connection(String, String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "后端响应无效"
        case .server(let message):
            return message
        case .connection(let url, let reason):
            return "无法连接后端 \(url)。请确认 Flask 服务正在运行。\(reason)"
        }
    }
}

private extension Data {
    mutating func appendString(_ string: String) {
        append(Data(string.utf8))
    }
}

private struct StatsView: View {
    let records: [ExpenseRecord]
    let monthlyTotal: Double
    @State private var selectedRange = "月"
    @State private var selectedTrendIndex: Int?
    private let ranges = ["月", "年"]

    private var rangeRecords: [ExpenseRecord] {
        guard let interval = currentInterval else {
            return records
        }
        return records.filter { $0.date >= interval.start && $0.date < interval.end }
    }

    private var rangeTotal: Double {
        rangeRecords.reduce(0) { $0 + $1.amountValue }
    }

    private var categoryRows: [(name: String, amount: Double, progress: CGFloat, color: Color)] {
        let grouped = Dictionary(grouping: rangeRecords, by: \.category)
        let totals = grouped.mapValues { values in values.reduce(0) { $0 + $1.amountValue } }
        let maxAmount = max(totals.values.max() ?? 1, 1)
        return grouped
            .map { key, values in
                let amount = totals[key] ?? 0
                return (name: key, amount: amount, progress: CGFloat(amount / maxAmount), color: values.first?.color ?? AppColors.green)
            }
            .sorted { $0.amount > $1.amount }
    }

    private var currentInterval: DateInterval? {
        let calendar = Calendar.current
        let now = Date()
        switch selectedRange {
        case "年":
            return calendar.dateInterval(of: .year, for: now)
        default:
            return calendar.dateInterval(of: .month, for: now)
        }
    }

    private var summaryTitle: String {
        switch selectedRange {
        case "年": return Self.yearFormatter.string(from: Date()) + "总支出"
        default: return Self.monthFormatter.string(from: Date()) + "总支出"
        }
    }

    private var summaryChip: String {
        switch selectedRange {
        case "年": return "12 月"
        default: return "\(Calendar.current.range(of: .day, in: .month, for: Date())?.count ?? 30) 天"
        }
    }

    private var trendDetail: String {
        switch selectedRange {
        case "年": return "按月汇总"
        default: return "按周汇总"
        }
    }

    private var trendRows: [(label: String, amount: Double, height: CGFloat)] {
        let calendar = Calendar.current
        let now = Date()
        let buckets: [(label: String, start: Date, end: Date)] = {
            switch selectedRange {
            case "年":
                guard let year = calendar.dateInterval(of: .year, for: now) else { return [] }
                return (0..<12).compactMap { offset in
                    guard let start = calendar.date(byAdding: .month, value: offset, to: year.start),
                          let interval = calendar.dateInterval(of: .month, for: start) else { return nil }
                    return (Self.monthOnlyFormatter.string(from: interval.start), interval.start, interval.end)
                }
            default:
                guard let month = calendar.dateInterval(of: .month, for: now) else { return [] }
                var result: [(label: String, start: Date, end: Date)] = []
                var start = month.start
                var index = 1
                while start < month.end {
                    guard let rawEnd = calendar.date(byAdding: .day, value: 7, to: start) else { break }
                    let end = min(rawEnd, month.end)
                    result.append(("第\(index)周", start, end))
                    start = end
                    index += 1
                }
                return result
            }
        }()

        let amounts = buckets.map { bucket in
            rangeRecords
                .filter { $0.date >= bucket.start && $0.date < bucket.end }
                .reduce(0) { $0 + $1.amountValue }
        }
        let maxAmount = max(amounts.max() ?? 0, 1)

        return zip(buckets, amounts).map { bucket, amount in
            (bucket.label, amount, amount == 0 ? 14 : max(30, CGFloat(amount / maxAmount) * 112))
        }
    }

    var body: some View {
        AppScreen(title: "统计", trailingIcon: "calendar") {
            RangeSegmentedControl(ranges: ranges, selection: $selectedRange)
                .onChange(of: selectedRange) { _, _ in
                    selectedTrendIndex = nil
                }

            SummaryCard(
                eyebrow: summaryTitle,
                amount: formatCurrency(rangeTotal),
                chip: summaryChip
            )
            .padding(.top, 14)

            ChartCard(title: "趋势图", detail: trendDetail) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: 12) {
                        ForEach(Array(trendRows.enumerated()), id: \.offset) { index, row in
                            TrendBar(
                                label: row.label,
                                amount: formatCompactCurrency(row.amount),
                                height: row.height,
                                isSelected: selectedTrendIndex == index
                            ) {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                    selectedTrendIndex = selectedTrendIndex == index ? nil : index
                                }
                            }
                            .frame(width: selectedRange == "年" ? 46 : 58)
                        }
                    }
                    .frame(minWidth: selectedRange == "年" ? 620 : 0)
                }
                .frame(height: 172, alignment: .bottom)
                .padding(.top, 12)
            }
            .padding(.top, 12)

            ChartCard(title: "分布图", detail: "分类从高到低") {
                Group {
                    if categoryRows.isEmpty {
                        EmptyStateView(icon: "chart.bar.xaxis", title: "暂无统计数据", subtitle: "新增支出后会自动生成分类分布")
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 12) {
                                ForEach(categoryRows, id: \.name) { row in
                                    RankRow(
                                        name: row.name,
                                        amount: formatCompactCurrency(row.amount),
                                        progress: row.progress,
                                        color: row.color
                                    )
                                }
                            }
                        }
                        .frame(maxHeight: 154)
                    }
                }
                .padding(.top, 12)
            }
            .padding(.top, 12)
        }
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M/d"
        return formatter
    }()

    private static let monthOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月"
        return formatter
    }()

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M 月"
        return formatter
    }()

    private static let yearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy 年"
        return formatter
    }()
}

private struct RangeSegmentedControl: View {
    let ranges: [String]
    @Binding var selection: String

    var body: some View {
        RangeButtonControl(ranges: ranges, selection: $selection)
        .frame(height: 50)
    }
}

private struct RangeButtonControl: UIViewRepresentable {
    let ranges: [String]
    @Binding var selection: String

    func makeUIView(context: Context) -> UIStackView {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
        stackView.spacing = 12
        return stackView
    }

    func updateUIView(_ stackView: UIStackView, context: Context) {
        context.coordinator.ranges = ranges

        stackView.arrangedSubviews.forEach { view in
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        for (index, range) in ranges.enumerated() {
            let button = UIButton(type: .system)
            let isSelected = selection == range
            button.tag = index
            button.setTitle(range, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 14, weight: .heavy)
            button.setTitleColor(UIColor(isSelected ? AppColors.text : AppColors.muted), for: .normal)
            button.backgroundColor = UIColor(isSelected ? AppColors.blue.opacity(0.28) : Color.white.opacity(0.08))
            button.layer.cornerRadius = 8
            button.layer.cornerCurve = .continuous
            button.layer.borderWidth = 1
            button.layer.borderColor = UIColor(isSelected ? AppColors.blue.opacity(0.58) : AppColors.line).cgColor
            button.addTarget(context.coordinator, action: #selector(Coordinator.didTapButton(_:)), for: .touchUpInside)
            stackView.addArrangedSubview(button)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection, ranges: ranges)
    }

    final class Coordinator: NSObject {
        private let selection: Binding<String>
        var ranges: [String]

        init(selection: Binding<String>, ranges: [String]) {
            self.selection = selection
            self.ranges = ranges
        }

        @objc func didTapButton(_ sender: UIButton) {
            guard sender.tag >= 0, sender.tag < ranges.count else {
                return
            }
            let nextSelection = ranges[sender.tag]
            guard selection.wrappedValue != nextSelection else {
                return
            }
            selection.wrappedValue = nextSelection
        }
    }
}

private struct ChartCard<Content: View>: View {
    let title: String
    let detail: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 19, weight: .heavy))
                    .foregroundStyle(AppColors.text)
                Spacer()
                Text(detail)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.muted)
            }

            content
        }
        .padding(14)
        .background(AppColors.panel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(AppColors.line, lineWidth: 1))
        .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 12)
    }
}

private struct TrendBar: View {
    let label: String
    let amount: String
    let height: CGFloat
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(amount)
                    .font(.system(size: isSelected ? 11 : 10, weight: .heavy))
                    .foregroundStyle(isSelected ? AppColors.blue : AppColors.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .frame(height: 16)

                ZStack(alignment: .bottom) {
                    Color.clear
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: isSelected
                                ? [Color.white.opacity(0.95), AppColors.blue]
                                : [Color(red: 0.576, green: 0.773, blue: 0.992), Color(red: 0.145, green: 0.388, blue: 0.922)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: isSelected ? 30 : 26, height: height)
                        .shadow(color: isSelected ? AppColors.blue.opacity(0.34) : .clear, radius: 8, x: 0, y: 4)
                }
                .frame(height: 116, alignment: .bottom)

                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isSelected ? AppColors.text : AppColors.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(height: 16)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(height: 156, alignment: .bottom)
        .frame(maxWidth: .infinity)
    }
}

private struct RankRow: View {
    let name: String
    let amount: String
    let progress: CGFloat
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Text(name)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(AppColors.text)
                .frame(width: 58, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.09))
                    Capsule()
                        .fill(color)
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 8)

            Text(amount)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(AppColors.text)
                .frame(width: 58, alignment: .trailing)
        }
    }
}

private struct HistoryView: View {
    @Binding var records: [ExpenseRecord]
    @State private var searchText = ""

    private var normalizedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredRecords: [ExpenseRecord] {
        let sorted = records.sorted { $0.date > $1.date }
        guard !normalizedQuery.isEmpty else {
            return sorted
        }

        return sorted.filter { record in
            record.title.localizedCaseInsensitiveContains(normalizedQuery)
            || record.category.localizedCaseInsensitiveContains(normalizedQuery)
            || record.time.localizedCaseInsensitiveContains(normalizedQuery)
            || record.amount.localizedCaseInsensitiveContains(normalizedQuery)
            || Self.fullDateFormatter.string(from: record.date).localizedCaseInsensitiveContains(normalizedQuery)
        }
    }

    private var groupedRecords: [(date: Date, records: [ExpenseRecord])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredRecords) { record in
            calendar.startOfDay(for: record.date)
        }
        return grouped
            .map { ($0.key, $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        AppScreen(title: "历史", trailingIcon: "magnifyingglass") {
            SearchField(text: $searchText)
                .padding(.bottom, 8)

            if groupedRecords.isEmpty {
                if normalizedQuery.isEmpty {
                    EmptyStateView(icon: "clock.arrow.circlepath", title: "暂无历史记录", subtitle: "保存支出后会按日期出现在这里")
                        .padding(.top, 24)
                } else {
                    EmptySearchView()
                        .padding(.top, 24)
                }
            } else {
                ForEach(groupedRecords, id: \.date) { group in
                    DayGroup(title: title(for: group.date), records: group.records) { record in
                        delete(record)
                    }
                }
            }
        }
    }

    private func delete(_ record: ExpenseRecord) {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            records.removeAll { $0.id == record.id }
        }
    }

    private func title(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "今天 · " + Self.dayTitleFormatter.string(from: date)
        }
        if calendar.isDateInYesterday(date) {
            return "昨天 · " + Self.dayTitleFormatter.string(from: date)
        }
        return Self.weekdayFormatter.string(from: date) + " · " + Self.dayTitleFormatter.string(from: date)
    }

    private static let dayTitleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M 月 d 日"
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEEE"
        return formatter
    }()

    private static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()
}

private struct SearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppColors.muted)

            TextField("搜索标题、分类、金额", text: $text)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColors.text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .frame(height: 28)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppColors.muted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(AppColors.panel.opacity(0.86), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(AppColors.line, lineWidth: 1))
    }
}

private struct EmptySearchView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(AppColors.muted)

            Text("没有找到匹配记录")
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(AppColors.text)

            Text("换一个标题、分类或金额试试")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(AppColors.panel.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(AppColors.line, lineWidth: 1))
    }
}

private struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(AppColors.muted)

            Text(title)
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(AppColors.text)

            Text(subtitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(AppColors.panel.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(AppColors.line, lineWidth: 1))
    }
}

private struct DayGroup: View {
    let title: String
    let records: [ExpenseRecord]
    let onDelete: (ExpenseRecord) -> Void

    private var total: Double {
        records.reduce(0) { $0 + $1.amountValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 19, weight: .heavy))
                    .foregroundStyle(AppColors.text)
                Spacer()
                Text("-" + formatPlainCurrency(total))
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(AppColors.red)
            }
            .padding(.top, 12)

            VStack(spacing: 10) {
                ForEach(records) { record in
                    ExpenseRow(record: record) {
                        onDelete(record)
                    }
                }
            }
        }
        .padding(.bottom, 8)
    }
}

private struct SettingsView: View {
    @Binding var categories: [CategoryItem]
    @Binding var records: [ExpenseRecord]
    @State private var showingAddCategory = false
    @State private var editingCategory: CategoryItem?
    @State private var showingClearConfirmation = false
    @State private var showingCSVExporter = false
    @State private var csvExportURL: URL?

    var body: some View {
        AppScreen(title: "设置", trailingIcon: "questionmark.circle") {
            HStack(alignment: .lastTextBaseline) {
                Text("分类管理")
                    .font(.system(size: 19, weight: .heavy))
                    .foregroundStyle(AppColors.text)

                Spacer()

                Button {
                    showingAddCategory = true
                } label: {
                    Label("新增", systemImage: "plus")
                        .font(.system(size: 13, weight: .heavy))
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppColors.blue)
            }
            .padding(.top, 18)
            .padding(.bottom, 10)

            SettingsGroup {
                ForEach(categories) { category in
                    Button {
                        editingCategory = category
                    } label: {
                        SettingRow(icon: category.icon, iconColor: category.color, title: category.name, value: "编辑")
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("数据管理")
                .font(.system(size: 19, weight: .heavy))
                .foregroundStyle(AppColors.text)
                .padding(.top, 18)
                .padding(.bottom, 10)

            SettingsGroup {
                Button {
                    csvExportURL = CSVExporter.export(records)
                    showingCSVExporter = csvExportURL != nil
                } label: {
                    SettingRow(icon: "square.and.arrow.up.fill", iconColor: AppColors.blue, title: "导出 CSV 数据", subtitle: "支出记录表格文件", value: "\(records.count) 笔")
                }
                .buttonStyle(.plain)

                Button(role: .destructive) {
                    showingClearConfirmation = true
                } label: {
                    SettingRow(icon: "trash.fill", iconColor: AppColors.red, title: "清除所有数据", subtitle: "操作前二次确认", isDanger: true)
                }
                .buttonStyle(.plain)
            }
        }
        .alert("清除所有数据？", isPresented: $showingClearConfirmation) {
            Button("取消", role: .cancel) {}
            Button("清除", role: .destructive) {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                    LocalStore.clearAllData()
                    records.removeAll()
                    categories = defaultCategories
                }
            }
        } message: {
            Text("所有本地支出记录和自定义分类都会被删除，分类会恢复为默认分类。")
        }
        .sheet(isPresented: $showingAddCategory) {
            CategoryEditorSheet(category: nil) { category in
                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                    categories.append(category)
                }
            } onDelete: { _ in
            }
                .presentationDetents([.height(500)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(18)
        }
        .sheet(item: $editingCategory) { category in
            CategoryEditorSheet(category: category) { updatedCategory in
                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                    if let index = categories.firstIndex(where: { $0.id == updatedCategory.id }) {
                        categories[index] = updatedCategory
                    }
                }
            } onDelete: { deletedCategory in
                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                    categories.removeAll { $0.id == deletedCategory.id }
                }
            }
                .presentationDetents([.height(550)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(18)
        }
        .sheet(isPresented: $showingCSVExporter) {
            if let csvExportURL {
                ActivityView(activityItems: [csvExportURL])
            }
        }
    }
}

private struct SettingsGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(AppColors.panel.opacity(0.86), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(AppColors.line, lineWidth: 1))
    }
}

private struct SettingRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    var subtitle: String? = nil
    var value: String? = nil
    var isDanger = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(iconColor, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(isDanger ? AppColors.red : AppColors.text)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.muted)
                }
            }

            Spacer(minLength: 8)

            if let value {
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.muted)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppColors.muted)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 66)
        .padding(.vertical, subtitle == nil ? 0 : 6)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppColors.line)
                .frame(height: 1)
                .padding(.leading, 68)
        }
    }
}

private enum CSVExporter {
    static func export(_ records: [ExpenseRecord]) -> URL? {
        let sortedRecords = records.sorted { $0.date > $1.date }
        let header = ["日期", "时间", "标题", "分类", "金额"].joined(separator: ",")
        let rows = sortedRecords.map { record in
            [
                csvEscape(Self.dateFormatter.string(from: record.date)),
                csvEscape(record.time),
                csvEscape(record.title),
                csvEscape(record.category),
                csvEscape(record.amountValue.formatted(.number.precision(.fractionLength(2))))
            ].joined(separator: ",")
        }
        let csv = ([header] + rows).joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("VoiceAccount-支出记录.csv")

        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    private static func csvEscape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct CategoryEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let category: CategoryItem?
    let onSave: (CategoryItem) -> Void
    let onDelete: (CategoryItem) -> Void
    @State private var name: String
    @State private var selectedIcon: String
    @State private var selectedColorHex: String

    private let icons = [
        "fork.knife",
        "car.fill",
        "bag.fill",
        "house.fill",
        "gamecontroller.fill",
        "film.fill",
        "airplane",
        "heart.text.square.fill",
        "music.note",
        "book.fill",
        "cross.case.fill",
        "figure.run",
        "phone.fill",
        "pawprint.fill",
        "ellipsis.circle.fill"
    ]
    private let colorHexes = [
        AppColors.pinkHex,
        AppColors.orangeHex,
        AppColors.tealHex,
        AppColors.blueHex,
        AppColors.purpleHex,
        AppColors.greenHex,
        AppColors.slateHex
    ]

    init(category: CategoryItem?, onSave: @escaping (CategoryItem) -> Void, onDelete: @escaping (CategoryItem) -> Void) {
        self.category = category
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: category?.name ?? "娱乐")
        _selectedIcon = State(initialValue: category?.icon ?? "gamecontroller.fill")
        _selectedColorHex = State(initialValue: category?.colorHex ?? AppColors.pinkHex)
    }

    var body: some View {
        SheetShell(title: category == nil ? "新增分类" : "编辑分类", close: { dismiss() }) {
            VStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("分类名称")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(AppColors.muted)

                    TextField("分类名", text: $name)
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(AppColors.text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .frame(height: 28)
                }
                .padding(.horizontal, 12)
                .frame(height: 54)
                .background(AppColors.panelSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(AppColors.line, lineWidth: 1))

                OptionBlock(title: "选择图标") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                        ForEach(icons, id: \.self) { icon in
                            OptionButton(isSelected: selectedIcon == icon) {
                                selectedIcon = icon
                            } content: {
                                Image(systemName: icon)
                            }
                        }
                    }
                }

                OptionBlock(title: "背景色") {
                    HStack(spacing: 8) {
                        ForEach(colorHexes, id: \.self) { colorHex in
                            OptionButton(isSelected: selectedColorHex == colorHex) {
                                selectedColorHex = colorHex
                            } content: {
                                Circle()
                                    .fill(Color(hex: colorHex))
                                    .frame(width: 28, height: 28)
                            }
                        }
                    }
                }

                HStack(spacing: 12) {
                    Image(systemName: selectedIcon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Color(hex: selectedColorHex), in: Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(name.isEmpty ? "未命名分类" : name)
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundStyle(AppColors.text)
                        Text("保存后可用于记账分类")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppColors.muted)
                    }

                    Spacer()
                }
                .padding(12)
                .background(AppColors.panelSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(AppColors.line, lineWidth: 1))

                PrimaryButton(title: "保存分类") {
                    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmedName.isEmpty else {
                        return
                    }

                    let savedCategory = CategoryItem(
                        id: category?.id ?? UUID(),
                        name: trimmedName,
                        icon: selectedIcon,
                        colorHex: selectedColorHex
                    )
                    onSave(savedCategory)
                    dismiss()
                }

                if let category {
                    Button(role: .destructive) {
                        onDelete(category)
                        dismiss()
                    } label: {
                        Label("删除分类", systemImage: "trash.fill")
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundStyle(AppColors.red)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(AppColors.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct SheetShell<Content: View>: View {
    let title: String
    let close: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 19, weight: .heavy))
                    .foregroundStyle(AppColors.text)

                Spacer()

                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppColors.muted)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 12)

            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColors.panel)
    }
}

private struct EditableField: View {
    let label: String
    @Binding var text: String
    var prefix: String? = nil
    var placeholder = ""
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(AppColors.muted)

            HStack(spacing: 7) {
                if let prefix {
                    Text(prefix)
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(AppColors.text)
                }

                TextField(placeholder, text: $text)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(AppColors.text)
                    .keyboardType(keyboard)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .padding(.horizontal, 15)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.white.opacity(0.13), lineWidth: 1))
    }
}

private struct DateField: View {
    let label: String
    @Binding var date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(AppColors.muted)

            DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .tint(AppColors.blue)
                .colorScheme(.dark)
                .font(.system(size: 17, weight: .bold))
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .padding(.horizontal, 15)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.white.opacity(0.13), lineWidth: 1))
    }
}

private struct FormField: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(AppColors.muted)

            Text(value)
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(AppColors.text)
        }
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        .padding(.horizontal, 12)
        .background(AppColors.panelSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(AppColors.line, lineWidth: 1))
    }
}

private struct CategoryChoice: View {
    let title: String
    let icon: String
    var selected = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                Text(title)
                    .font(.system(size: 11, weight: .heavy))
            }
            .foregroundStyle(selected ? AppColors.blue : AppColors.muted)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(selected ? AppColors.blue.opacity(0.14) : AppColors.panelSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(selected ? AppColors.blue.opacity(0.55) : AppColors.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct OptionBlock<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(AppColors.text)

            content
        }
    }
}

private struct OptionButton<Content: View>: View {
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        Button(action: action) {
            content
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AppColors.text)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(isSelected ? AppColors.blue.opacity(0.14) : AppColors.panelSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(isSelected ? AppColors.blue.opacity(0.62) : AppColors.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct PrimaryButton: View {
    let title: String
    var action: () -> Void = {}

    var body: some View {
        Button(title, action: action)
            .font(.system(size: 16, weight: .heavy))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(AppColors.blue, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
}
