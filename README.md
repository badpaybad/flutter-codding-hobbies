# flutter-codding-hobbies

Check folder "google guider" for how to implement Notification in android with fcm, and other firebase services, add google service to grade build

                AppContext to init data of application
                Init firebase app, google auth, firebase realtimedb
                
                NotificationHelper to init notification FCM
                do you dispatched noti with this function:
                    _firebaseMessagingBackgroundHandler

                do you on touch, tab, click to notification with this function:  
                _do_when_use_touch_tab_into_notification_showed

                Handle notification fcm foreground

                 NotificationHelper.instance.onForgroundNotification((msg) async {})
                  

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


# ROS https://www.ros.org/

If you work with ROS1 noetic https://www.ros.org/ 

Many thanks to https://github.com/Sashiri/ros_nodes 

You should check RosAppContext for usage of pub sub in ros 
                
                and in main.dart must call RosAppContext.instance.init


### setup ros

Check here http://wiki.ros.org/noetic/Installation/Ubuntu  
                
                //or run bash shell for Ubuntu 20.04
                ./ros/setupros.sh

                //after setup
                //open terminal just type: 
                roscore 

You will get similar ,  ROS_MASTER_URI=http://192.168.1.8:11311/ will become to config for RosAppContext.instance.init

Check ros_config.dart
                
                Press Ctrl-C to interrupt
                Done checking log file disk usage. Usage is <1GB.

                started roslaunch server http://192.168.1.8:34899/
                ros_comm version 1.15.15

                ....    
                NODES

                auto-starting new master
                process[master]: started with pid [55115]
                ROS_MASTER_URI=http://192.168.1.8:11311/

                setting /run_id to c4d33a0e-9423-11ed-9925-098c12ebf2ed
                process[rosout-1]: started with pid [55148]
                started core service [/rosout]


