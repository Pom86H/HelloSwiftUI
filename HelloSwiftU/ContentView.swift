import SwiftUI

struct ContentView: View {
    // MARK: - State Variables
    @State private var newItem: String = "" // 新しいアイテムの入力用
    @State private var selectedCategory: String = "食品" // アイテム追加時に選択されるカテゴリ
    @State private var shoppingList: [String: [String]] = [:] // 買い物リストのデータ (カテゴリごとのアイテムの辞書)
    @State private var categories: [String] = ["食品", "日用品", "その他"] // カテゴリの一覧
    @State private var newCategory: String = "" // 新しいカテゴリの入力用
    @State private var showCategoryInput: Bool = false // 新しいカテゴリ入力フィールドの表示/非表示

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
        NavigationView {
            VStack(spacing: 10) {
                // アプリのタイトル
                Text("To Do List 🛒")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top, 2)

                // 新しいアイテムの追加セクション
                HStack(spacing: 8) {
                    TextField("買うもの", text: $newItem)
                        .padding(8)
                        .background(.ultraThinMaterial) // 半透明の背景
                        .cornerRadius(8)
                        .font(.subheadline)

                    Picker("", selection: $selectedCategory) {
                        ForEach(categories, id: \.self) { category in
                            Text(category)
                        }
                    }
                    .pickerStyle(MenuPickerStyle()) // メニュー形式のピッカー
                    .frame(width: 90)

                    Button("追加") {
                        addItem() // アイテム追加メソッドの呼び出し
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                    .font(.subheadline)
                    .disabled(newItem.isEmpty) // 入力フィールドが空の場合はボタンを無効化
                }

                // 買い物リストの表示セクション
                ScrollView {
                    LazyVStack(spacing: 8) {
                        // 各カテゴリをループ
                        ForEach(categories, id: \.self) { category in
                            // そのカテゴリにアイテムが存在する場合のみ表示
                            if let items = shoppingList[category], !items.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(category) // カテゴリ名
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                        Spacer()
                                        // 編集モードで、かつ削除可能なカテゴリの場合、削除ボタンを表示
                                        if editMode?.wrappedValue == .active && canDeleteCategory(category) {
                                            Button(action: {
                                                categoryToDelete = category
                                                showDeleteCategoryConfirmation = true
                                            }) {
                                                Image(systemName: "trash") // ゴミ箱アイコン
                                                    .foregroundColor(.red)
                                            }
                                            .buttonStyle(BorderlessButtonStyle()) // ボタンのスタイルをリセット
                                            // カテゴリ削除確認ダイアログ
                                            .confirmationDialog("カテゴリを削除しますか？", isPresented: $showDeleteCategoryConfirmation, titleVisibility: .visible) {
                                                if let category = categoryToDelete, canDeleteCategory(category) {
                                                    Button("削除", role: .destructive) {
                                                        deleteCategory(category) // カテゴリ削除メソッドの呼び出し
                                                        categoryToDelete = nil
                                                    }
                                                }
                                                Button("キャンセル", role: .cancel) {
                                                    categoryToDelete = nil
                                                }
                                            }
                                        }
                                    }
                                    // 各アイテムをループ
                                    ForEach(Array(items.enumerated()), id: \.element) { index, item in
                                        HStack {
                                            // 編集モードの場合、並び替えハンドルを表示
                                            if editMode?.wrappedValue == .active {
                                                Image(systemName: "line.3.horizontal")
                                                    .foregroundColor(.gray)
                                                    .padding(.trailing, 4)
                                            }
                                            // アイテム削除ボタン (完了マークとして機能)
                                            Button(action: {
                                                deleteItem(item, from: category) // アイテム削除メソッドの呼び出し
                                            }) {
                                                Image(systemName: "circle") // 未完了の丸アイコン
                                                    .foregroundColor(.gray)
                                            }
                                            .buttonStyle(PlainButtonStyle()) // ボタンのスタイルをリセット
                                            .padding(.trailing, 4)

                                            // 編集モードで、かつ現在タップされているアイテムが編集対象の場合、TextFieldを表示
                                            if editMode?.wrappedValue == .active && editingItem?.category == category && editingItem?.originalItem == item {
                                                TextField("アイテム名を編集", text: $editedItemName, onCommit: {
                                                    // 編集が確定されたらアイテムを更新し、編集モードを終了
                                                    updateItem(originalItem: item, in: category, with: editedItemName)
                                                    editingItem = nil
                                                })
                                                .font(.subheadline)
                                                .autocorrectionDisabled(true) // 自動修正を無効化
                                                .textInputAutocapitalization(.never) // 自動大文字化を無効化
                                            } else {
                                                // 通常表示の場合、Textを表示し、編集モードでタップされたら編集可能にする
                                                Text(item)
                                                    .font(.subheadline)
                                                    .onTapGesture {
                                                        if editMode?.wrappedValue == .active {
                                                            editingItem = (category: category, originalItem: item) // 編集対象を設定
                                                            editedItemName = item // TextFieldの初期値を現在のアイテム名に設定
                                                        }
                                                    }
                                            }
                                            Spacer()
                                        }
                                        .padding(8)
                                        .background(.ultraThinMaterial)
                                        .cornerRadius(6)
                                        .shadow(color: (categoryColors[category] ?? .gray).opacity(0.2), radius: 1, x: 0, y: 1)
                                        .padding(.horizontal, 4)
                                        .listRowSeparator(.hidden) // リストの区切り線を非表示に
                                    }
                                    // アイテムの並び替え機能
                                    .onMove { indices, newOffset in
                                        moveItems(in: category, indices: indices, newOffset: newOffset)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top, 4)
                }

                // 削除したアイテムの履歴セクション
                if !deletedItems.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("削除したアイテム（履歴）")
                            .font(.subheadline)
                            .padding(.leading)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(deletedItems, id: \.self) { item in
                                    Button(action: {
                                        restoreDeletedItem(item) // 削除アイテムを復元
                                    }) {
                                        Text(item)
                                            .font(.caption)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(.ultraThinMaterial)
                                            .cornerRadius(10)
                                            .shadow(radius: 1)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }

                // カテゴリ追加ボタン
                Button(action: {
                    withAnimation {
                        showCategoryInput.toggle() // カテゴリ入力フィールドの表示/非表示を切り替え
                    }
                }) {
                    Text(showCategoryInput ? "カテゴリ入力を隠す" : "＋ カテゴリを追加")
                        .font(.subheadline)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                }
                .padding(.top, 4)

                // 新しいカテゴリの入力セクション
                if showCategoryInput {
                    HStack {
                        TextField("新しいカテゴリー名", text: $newCategory)
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                            .font(.subheadline)

                        Button("追加") {
                            addCategory() // カテゴリ追加メソッドの呼び出し
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                        .font(.subheadline)
                        .disabled(newCategory.trimmingCharacters(in: .whitespaces).isEmpty) // 空の場合は無効化
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom)
            .onAppear {
                // ビューが表示されたときに保存されたデータを読み込む
                loadItems()
                loadDeletedItems()
            }
        }
        .navigationBarTitle("買い物リスト") // ナビゲーションバーのタイトル
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                // 標準のEditButtonを使用
                EditButton()
            }
        }
        .environment(\.editMode, editMode) // 環境変数に編集モードの状態をバインド
    }
}

// MARK: - 機能メソッドの追加 (Extension)
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
        newCategory = ""
    }

    /// UserDefaultsから買い物リストのデータを読み込みます。
    private func loadItems() {
        if let data = UserDefaults.standard.data(forKey: shoppingListKey),
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

    /// 買い物リストのデータをUserDefaultsに保存します。
    private func saveItems() {
        if let data = try? JSONEncoder().encode(shoppingList) {
            UserDefaults.standard.set(data, forKey: shoppingListKey)
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
