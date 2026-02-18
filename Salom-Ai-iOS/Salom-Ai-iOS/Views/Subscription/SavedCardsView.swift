//
//  SavedCardsView.swift
//  Salom-Ai-iOS
//
//  List of saved cards with delete action.
//

import SwiftUI

struct SavedCardsView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var cardToDelete: SavedCard?
    @State private var showDeleteAlert = false

    var body: some View {
        ZStack {
            SalomTheme.Gradients.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    if subscriptionManager.savedCards.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "creditcard")
                                .font(.system(size: 40))
                                .foregroundColor(SalomTheme.Colors.textSecondary)
                            Text("Saqlangan kartalar yo'q")
                                .font(.headline)
                                .foregroundColor(SalomTheme.Colors.textSecondary)
                        }
                        .padding(.top, 60)
                    } else {
                        ForEach(subscriptionManager.savedCards) { card in
                            CardRow(card: card) {
                                cardToDelete = card
                                showDeleteAlert = true
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Saqlangan kartalar")
                    .font(.headline)
                    .foregroundColor(.white)
            }
        }
        .task {
            await subscriptionManager.fetchSavedCards()
        }
        .alert("Kartani o'chirish", isPresented: $showDeleteAlert) {
            Button("O'chirish", role: .destructive) {
                if let card = cardToDelete {
                    Task {
                        let _ = await subscriptionManager.deleteCard(id: card.id)
                    }
                }
            }
            Button("Bekor qilish", role: .cancel) {}
        } message: {
            if let card = cardToDelete {
                Text("\(card.maskedNumber) kartasini o'chirmoqchimisiz? Avtomatik yangilanish o'chiriladi.")
            }
        }
    }
}

private struct CardRow: View {
    let card: SavedCard
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "creditcard.fill")
                .font(.title2)
                .foregroundColor(SalomTheme.Colors.accentPrimary)
                .frame(width: 44, height: 44)
                .background(SalomTheme.Colors.accentPrimary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(card.maskedNumber)
                    .font(.headline)
                    .foregroundColor(.white)

                Text(card.phoneHint)
                    .font(.caption)
                    .foregroundColor(SalomTheme.Colors.textSecondary)
            }

            Spacer()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.body)
                    .foregroundColor(.red.opacity(0.8))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }
}
