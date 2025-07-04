import SwiftUI
import WidgetKit

struct ContentView: View {
    // MARK: - State Variables
    @State private var newItem: String = "" // 新しいアイテムの入力用
    @State private var selectedCategory: String = "食品" // アイテム追加時に選択されるカテゴリ
    @State private var shoppingList: [String: [String]] = [:] // 買い物リストのデータ (カテゴリごとのアイテムの辞書)
    @State private var categories: [String] = ["食品", "日用品", "その他"] // カテゴリの一覧
    @State private var newCategory: String = "" // 新しいカテゴリの入力用
    @State private var showAddTaskSheet = false
    @State private var showAddItemSheet = false
    @State private var showAddCategorySheet = false

    @State private var deletedItems: [String] = [] // 削除されたアイテムの履歴

    @State private var categoryToDelete: String? = nil // 削除確認ダイアログで選択されたカテゴリ
    @State private var showDeleteCategoryConfirmation = false // カテゴリ削除確認ダイアログの表示/非表示

    @Environment(\.editMode) private var editMode // SwiftUIの編集モード環境変数

    // 編集中のアイテムを追跡するためのState変数
    // (category: 編集中のアイテムのカテゴリ, originalItem: 編集前のアイテム名)
    @State private var editingItem: (category: String, originalItem: String)? = nil
    @State private var editedItemName: String = "" // 編集中のアイテムの新しい名前

    // MARK: - Constants
    private let shoppingListKey = "shoppingListKey" // UserDefaultsに買い物リストを保存するためのキー
    private let deletedItemsKey = "deletedItemsKey" // UserDefaultsに削除履歴を保存するためのキー

    // カテゴリごとの色を定義 (視覚的な区別のため)
    private let categoryColors: [String: Color] = [
        "食品": .green,
        "日用品": .blue,
        "その他": .gray
    ]

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                LottieView(filename: "Animation - 1751589879123")
                    .ignoresSafeArea()

                VStack(spacing: 10) {
                    List {
                        ForEach(categories, id: \.self) { category in
                            if let items = shoppingList[category], !items.isEmpty {
                                Section(header: headerView(for: category)) {
                                    ForEach(Array(items.enumerated()), id: \.element) { index, item in
                                        itemRow(for: item, in: category)
                                    }
                                    .onMove { indices, newOffset in
                                        moveItems(in: category, indices: indices, newOffset: newOffset)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)

                    if !deletedItems.isEmpty {
                        deletedItemsSection
                    }
                }
                .padding(.bottom, 60)

                plusButton
            }
            .navigationTitle("To Do 🛒")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(editMode?.wrappedValue == .active ? "完了" : "編集") {
                        withAnimation {
                            editMode?.wrappedValue = editMode?.wrappedValue == .active ? .inactive : .active
                        }
                    }
                }
            }
            .environment(\.editMode, editMode)
            .onAppear {
                loadItems()
                loadDeletedItems()
                loadCategories()
            }
        }
        // --- シート群はbodyの末尾に配置 ---
        .sheet(isPresented: $showAddTaskSheet) {
            NavigationView {
                VStack(spacing: 20) {
                    Text("追加するものを選んでください")
                        .font(.headline)
                        .padding(.top)

                    Button(action: {
                        showAddTaskSheet = false
                        showAddItemSheet = true
                    }) {
                        Label("リストにアイテムを追加", systemImage: "list.bullet")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(10)
                    }

                    Button(action: {
                        showAddTaskSheet = false
                        showAddCategorySheet = true
                    }) {
                        Label("新しいカテゴリを追加", systemImage: "folder.badge.plus")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(10)
                    }

                    Spacer()
                }
                .padding()
                .navigationTitle("追加")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showAddTaskSheet = false
                        }) {
                            Image(systemName: "xmark")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAddItemSheet) {
            NavigationView {
                VStack(spacing: 16) {
                    TextField("買うもの", text: $newItem)
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                        .font(.subheadline)

                    Picker("カテゴリ", selection: $selectedCategory) {
                        ForEach(categories, id: \.self) { category in
                            Text(category)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())

                    Button("追加") {
                        addItem()
                        showAddItemSheet = false
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                    .disabled(newItem.isEmpty)

                    Spacer()
                }
                .padding()
                .navigationTitle("新しいタスク")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showAddItemSheet = false
                        }) {
                            Image(systemName: "xmark")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAddCategorySheet) {
            NavigationView {
                VStack(spacing: 16) {
                    TextField("新しいカテゴリー名", text: $newCategory)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                        .font(.subheadline)

                    Button("追加") {
                        addCategory()
                        newCategory = ""
                        showAddCategorySheet = false
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                    .font(.subheadline)
                    .disabled(newCategory.trimmingCharacters(in: .whitespaces).isEmpty)

                    Spacer()
                }
                .padding()
                .navigationTitle("新しいカテゴリ")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showAddCategorySheet = false
                        }) {
                            Image(systemName: "xmark")
                        }
                    }
                }
            }
        }
    }

private func headerView(for category: String) -> some View {
    HStack {
        Text(category)
            .font(.subheadline)
            .fontWeight(.semibold)
        Spacer()
        if editMode?.wrappedValue == .active && canDeleteCategory(category) {
            Button {
                categoryToDelete = category
                showDeleteCategoryConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .confirmationDialog("カテゴリを削除しますか？", isPresented: $showDeleteCategoryConfirmation) {
                if let category = categoryToDelete {
                    Button("削除", role: .destructive) { deleteCategory(category) }
                    Button("キャンセル", role: .cancel) { categoryToDelete = nil }
                }
            }
        }
    }
}

private func itemRow(for item: String, in category: String) -> some View {
    HStack {
        if editMode?.wrappedValue == .active {
            Image(systemName: "line.3.horizontal").foregroundColor(.gray)
        }
        Button {
            deleteItem(item, from: category)
        } label: {
            Image(systemName: "circle").foregroundColor(.gray)
        }
        .buttonStyle(.plain)

        if editMode?.wrappedValue == .active && editingItem?.originalItem == item {
            TextField("アイテム名", text: $editedItemName, onCommit: {
                updateItem(originalItem: item, in: category, with: editedItemName)
                editingItem = nil
            })
        } else {
            Text(item).onTapGesture {
                if editMode?.wrappedValue == .active {
                    editingItem = (category, item)
                    editedItemName = item
                }
            }
        }
    }
    .padding(8)
    .background(.ultraThinMaterial)
    .cornerRadius(6)
    .padding(.horizontal, 4)
}

private var deletedItemsSection: some View {
    VStack(alignment: .leading) {
        Text("削除したアイテム（履歴）")
            .font(.subheadline)
            .padding(.leading)
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(deletedItems, id: \.self) { item in
                    Button { restoreDeletedItem(item) } label: {
                        Text(item)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .cornerRadius(10)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

private var plusButton: some View {
    Button {
        showAddTaskSheet = true
    } label: {
        Image(systemName: "plus")
            .foregroundColor(.white)
            .font(.system(size: 24, weight: .bold))
            .frame(width: 56, height: 56)
            .background(Color.accentColor)
            .clipShape(Circle())
            .shadow(radius: 4)
            .padding()
    }
}


// MARK: - 機能メソッドの追加 (Extension)
}

extension ContentView {
    /// 新しいアイテムをリストに追加します。
    private func addItem() {
        let trimmedItem = newItem.trimmingCharacters(in: .whitespaces)
        guard !trimmedItem.isEmpty else { return }

        withAnimation {
            var items = shoppingList[selectedCategory] ?? []
            items.append(trimmedItem)
            shoppingList[selectedCategory] = items
        }

        newItem = ""
        saveItems() // 変更を保存
    }

    /// 指定されたカテゴリを削除します。
    private func deleteCategory(_ category: String) {
        withAnimation {
            categories.removeAll { $0 == category }
            shoppingList.removeValue(forKey: category)
        }
        saveItems() // 変更を保存
        // WidgetCenter.shared.reloadAllTimelines() // ← 削除: WidgetCenterの呼び出しはsaveItems()で行う
    }

    /// 指定されたカテゴリからアイテムを削除し、削除履歴に追加します。
    private func deleteItem(_ item: String, from category: String) {
        guard var items = shoppingList[category] else { return }
        guard let index = items.firstIndex(of: item) else { return }

        let removed = items.remove(at: index)
        addDeletedItems([removed]) // 削除履歴に追加
        withAnimation {
            shoppingList[category] = items
        }
        saveItems() // 変更を保存
    }

    /// 削除履歴からアイテムを復元し、現在の選択カテゴリに追加します。
    private func restoreDeletedItem(_ item: String) {
        withAnimation {
            var items = shoppingList[selectedCategory] ?? []
            if !items.contains(item) { // 重複を避ける
                items.append(item)
                shoppingList[selectedCategory] = items
                saveItems() // 変更を保存
            }
            deletedItems.removeAll { $0 == item } // 履歴から削除
            saveDeletedItems() // 変更を保存
        }
    }

    /// 新しいカテゴリを追加します。
    private func addCategory() {
        let trimmedCategory = newCategory.trimmingCharacters(in: .whitespaces)
        guard !trimmedCategory.isEmpty, !categories.contains(trimmedCategory) else { return } // 空または重複は追加しない
        categories.append(trimmedCategory)
        saveCategories() // 保存を追加
        newCategory = ""
    }

    /// カテゴリのデータをUserDefaultsに保存します。
    private func saveCategories() {
        UserDefaults.standard.set(categories, forKey: "categoriesKey")
    }

    /// UserDefaultsからカテゴリデータを読み込みます。
    private func loadCategories() {
        if let saved = UserDefaults.standard.stringArray(forKey: "categoriesKey") {
            categories = saved
        }
    }

    /// App Group から買い物リストのデータを読み込みます。
    private func loadItems() {
        let sharedDefaults = UserDefaults(suiteName: "group.com.yourname.ToDo") // App Group名は適宜変更
        if let data = sharedDefaults?.data(forKey: shoppingListKey),
           let items = try? JSONDecoder().decode([String: [String]].self, from: data) {
            shoppingList = items
        }
    }

    /// UserDefaultsから削除履歴のデータを読み込みます。
    private func loadDeletedItems() {
        if let data = UserDefaults.standard.data(forKey: deletedItemsKey),
           let items = try? JSONDecoder().decode([String].self, from: data) {
            deletedItems = items
        }
    }

    /// 買い物リストのデータをApp Groupに保存します。
    private func saveItems() {
        if let data = try? JSONEncoder().encode(shoppingList) {
            let sharedDefaults = UserDefaults(suiteName: "group.com.yourname.ToDo") // App Group名は適宜変更
            sharedDefaults?.set(data, forKey: shoppingListKey)
            WidgetCenter.shared.reloadAllTimelines() // ウィジェット更新を即トリガー
        }
    }

    /// 削除履歴のデータをUserDefaultsに保存します。
    private func saveDeletedItems() {
        if let data = try? JSONEncoder().encode(deletedItems) {
            UserDefaults.standard.set(data, forKey: deletedItemsKey)
        }
    }

    /// 削除されたアイテムを履歴に追加します（最新5件を保持）。
    private func addDeletedItems(_ items: [String]) {
        for item in items {
            deletedItems.removeAll { $0 == item } // 既に存在する場合は削除して再追加
            deletedItems.insert(item, at: 0) // 先頭に追加
        }
        if deletedItems.count > 5 {
            deletedItems = Array(deletedItems.prefix(5)) // 最新5件に制限
        }
        saveDeletedItems() // 変更を保存
    }

    /// 指定されたカテゴリ内でアイテムの並び順を変更します。
    private func moveItems(in category: String, indices: IndexSet, newOffset: Int) {
        guard var items = shoppingList[category] else { return }
        items.move(fromOffsets: indices, toOffset: newOffset)
        shoppingList[category] = items
        saveItems() // 変更を保存
    }

    /// 指定されたカテゴリが削除可能かどうかを判定します（初期カテゴリは不可）。
    private func canDeleteCategory(_ category: String) -> Bool {
        !["食品", "日用品", "その他"].contains(category)
    }

    /// アイテム名を更新します。
    /// - Parameters:
    ///   - originalItem: 変更前のアイテム名
    ///   - category: アイテムが存在するカテゴリ
    ///   - newItemName: 新しいアイテム名
    private func updateItem(originalItem: String, in category: String, with newItemName: String) {
        let trimmedNewItemName = newItemName.trimmingCharacters(in: .whitespaces)
        guard !trimmedNewItemName.isEmpty else { return } // 空の場合は更新しない

        if var items = shoppingList[category], let index = items.firstIndex(of: originalItem) {
            items[index] = trimmedNewItemName
            shoppingList[category] = items
            saveItems() // 変更を保存
        }
    }
}

/*
    注意：このアプリは UserDefaults を用いてリスト内容・履歴を保存しているため、
    アプリを閉じたり端末を再起動してもデータは保持されます。
*/
