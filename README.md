# flutter-codding-hobbies

Check folder "google guider" for how to implement Notification in android with fcm, and other firebase services, add google service to grade build

                AppContext to init data of application
                Init firebase app, google auth, firebase realtimedb
                
                NotificationHelper to init notification FCM
                do you dispatched noti with this
                    _firebaseMessagingBackgroundHandler

                do you on touch to notification here
                _do_when_use_touch_tab_into_notification_showed

# Local data with hive 

To store local data we use hive, check folder "Repository"

# Restful api and upload multipart data

Check file HttpBase

# webrtc p2p 

### redis as signaling 

You can change to any push server or firebasedb, firestore

                Check to change redis as you own
                MessageBus at line 30

### WebRtcP2pVideoStreamPage

the flow of webrtc

                //main flow
                device1 -> create offer -> signaling redis publish to device2
                device2 -> setRemoteOffer( offerData)  created answer -> signaling redis publis to device 1
                device1 -> setRemoteAnswer( answerData) 

                //optional flow
                device1 -> ice on candidate -> signaling redis publish  to device 2
                device2 -> addCandidate( candidates )
            
                device2 -> ice on candidate -> signaling redis publish  to device 1
                device1 -> addCandidate( candidates )

                //quit screen flow
                device1 -> close -> signaling redis publish to device2
                device2 -> close peer
                    -> can click connect to do main flow

                device2 -> close -> signaling redis publish to device1
                device1 -> close peer 
                    -> can click connect to do main flow