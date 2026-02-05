import SwiftUI

struct NotificationModel: Identifiable, Codable {
    let id: Int
    let title: String
    let body: String
    let channel: String
    let is_read: Bool
    let created_at: String
}

struct NotificationHistoryView: View {
    @State private var notifications: [NotificationModel] = []
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else if notifications.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("No notifications yet")
                        .foregroundColor(.gray)
                }
            } else {
                List(notifications) { notification in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(notification.title)
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                            if !notification.is_read {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 8, height: 8)
                            }
                        }
                        
                        Text(notification.body)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .lineLimit(2)
                        
                        Text(formatDate(notification.created_at))
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.6))
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }
                .listStyle(PlainListStyle())
            }
        }
        .onAppear {
            fetchNotifications()
        }
    }
    
    private func fetchNotifications() {
        let url = APIClient.shared.baseURL.appendingPathComponent("notifications")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        components?.queryItems = [URLQueryItem(name: "limit", value: "20")]
        
        guard let finalUrl = components?.url else { return }
        
        var request = URLRequest(url: finalUrl)
        request.httpMethod = "GET"
        if let token = UserDefaults.standard.string(forKey: "accessToken") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let data = data {
                    do {
                        let decoder = JSONDecoder()
                        notifications = try decoder.decode([NotificationModel].self, from: data)
                    } catch {
                        print("Decoding error: \(error)")
                    }
                }
            }
        }.resume()
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}
