# UNI-verse 📱🎓  
**Connecting Students, Bridging the Gap**

[![Flutter](https://img.shields.io/badge/Flutter-Framework-blue?logo=flutter)](https://flutter.dev/)
[![Firebase](https://img.shields.io/badge/Firebase-Backend-yellow?logo=firebase)](https://firebase.google.com/)
[![Cloudinary](https://img.shields.io/badge/Cloudinary-Media%20Storage-lightblue?logo=cloudinary)](https://cloudinary.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Build](https://img.shields.io/badge/Build-Passing-brightgreen)]()
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-blue)]()

---

## 📱 Overview

**UNI-verse** is a mobile-first app built to connect university students by providing a centralized platform for information sharing, community support, and engagement. It features social functionalities, AI-powered chatbot support, secure login, and a clean, user-friendly interface. Perfect for universities aiming to enhance campus communication.

---
👨‍💻 Developed By

    Maaz Bin Hassan

    Hafsa Waseem

    Sadia Athar

## 🚀 Features

### 🔍 Lost and Found  
- Report, browse, and track lost/found items  
- Add item details with images  
- Comment and mark items as resolved  
- **AI-Based Categorization**: Automatically categorizes items like *electronics, ID cards, clothes, documents*, etc., based on text content  

### 👥 Peer Assistance  
- Ask or offer academic/non-academic help  
- Like and comment system  
- **AI Topic Tagging**: Automatically tags posts related to subjects like *programming, mathematics, engineering* into categories like *CS, Mathematics, Engineering*, etc.  
- Builds a supportive student network  

### 📊 Survey Lounge  
- Take and create surveys  
- Get instant feedback and analytics  
- Supports multiple question types  

### 📢 Event & Job Announcements  
- Post or explore campus events and job openings  
- Easy apply or RSVP feature  
- Smart filtering and search  

### 🤖 AI Chatbot  
- Instantly answers campus-related queries  
- Built using Dialogflow or OpenAI  
- Available 24/7 for general assistance  

### 👤 User Profiles  
- Google Sign-In and profile customization  
- Activity tracking and history view  
- Profile picture and display name management  

### ❤️ Like & Comment  
- Like posts and reply to discussions  
- Real-time updates  
- Threaded comments  

### 🔔 Notifications  
- Push notifications via Firebase Cloud Messaging  
- Real-time alerts for comments, likes, events, and more  

### 🔐 Authentication & Security  
- Google Sign-In  
- Two-Factor Authentication (2FA)  
- Secure with Firebase Auth and Firestore Rules  

---

## 🧠 AI-Based Categorization

- **Lost and Found**: Automatically classifies reported items using Natural Language Processing (NLP) into categories like:
  - Electronics
  - ID Cards
  - Documents
  - Clothing
  - Others

- **Peer Assistance**: AI scans question content to detect domain and auto-assigns categories like:
  - Computer Science (e.g., programming, coding)
  - Mathematics (e.g., algebra, calculus)
  - Engineering (e.g., circuits, mechanics)

This helps in better post discovery, organization, and faster response from relevant peers.

---

## 🧑‍💻 Tech Stack

| Layer         | Technology                     |
|---------------|---------------------------------|
| Frontend      | Flutter (Dart)                 |
| Backend       | Firebase (Firestore, Auth, FCM, Storage) |
| AI/ML         | Dialogflow / OpenAI (Chatbot, NLP Categorization) |
| Media Storage | Cloudinary                     |
| Notifications | Firebase Cloud Messaging (FCM)  |
| Routing       | go_router / auto_route         |
| State Mgmt    | provider / riverpod / flutter_bloc |
| UI Components | flutter_svg, carousel_slider, intl |

---

## 🖼️ Screenshots

> *(Add your app screenshots here by uploading to `/assets` or use Cloudinary links)*  
> `![Screenshot1](link)`  
> `![Screenshot2](link)`  

---

## 🔧 Setup Instructions

### 📋 Prerequisites
- Flutter SDK (latest stable)
- Firebase project with Auth, Firestore, and Storage
- Cloudinary account
- Android Studio or VSCode

### 🧑‍💻 Clone the Repository

```bash
git clone https://github.com/your-username/UNI-verse.git
cd UNI-verse
```

### 📦 Install Dependencies

```bash
flutter pub get
```

### 🔐 Configure Firebase

1. Create a Firebase Project  
2. Enable Google Sign-In, Firestore, FCM, and Storage  
3. Download and place `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)  
4. Set Firestore security rules

### 🖼️ Configure Cloudinary

Create a `.env` file or use secure secrets manager:
```env
CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_API_KEY=your_api_key
CLOUDINARY_API_SECRET=your_api_secret
```

### 🔒 Enable 2FA (Optional but Secure)
- Go to Firebase Console > Authentication > Multi-Factor Authentication
- Enable SMS-based second factor
- Update your sign-in flow

### ▶️ Run the App

```bash
flutter run
```

---

## 🧪 Testing

- Use Flutter’s built-in test framework
- Write unit tests and widget tests under `/test`
- Optionally use Firebase Test Lab for integration testing

---

## 📦 Deployment

- **Android**: Use `flutter build apk --release` or `flutter build appbundle`
- **iOS**: Build via Xcode and upload to App Store
- **Web**: Optional - Deploy with Firebase Hosting

---

## 🤝 Contributing

Contributions are welcome!  
To contribute:

1. Fork the repo  
2. Create your feature branch: `git checkout -b feature/your-feature`  
3. Commit your changes: `git commit -m 'Add feature'`  
4. Push to the branch: `git push origin feature/your-feature`  
5. Open a Pull Request


## 🙏 Acknowledgements

- Firebase by Google  
- Cloudinary  
- Testers and Students who helped shape the app
