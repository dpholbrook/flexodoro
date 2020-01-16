## Flexodoro

The Pomodoro Technique is very helpful for studying. The basic premise is that you focus for 25 minutes and then you take a 5 minute break. The technique helps increase focus and productivity. It also helps avoid procrastinating (just start the timer). The problem that I have run into with my Pomodoro timer is that it often interrupts my work flow. The solution is Flexodoro, a flexible Pomodoro Timer.
There are two parts to Flexodoro: Focus Mode and Rest Mode. The more time you focus, the more time you get to rest. Specifically, for every 5 minutes that you focus, you get 1 minute of Rest.

After 25 consecutive minutes in focus mode, a beep will notify you that it is time to take a break. But, if you are in the middle of something, you can keep going until you are finished or get tired. You can even adjust the beep time in settings.

When you are ready to rest, click the Rest button and the Rest Countdown will begin. When your rest time is expired, a timer will go off informing you that it is time to get back to work. If you don’t want to rest for the full amount of allocated time to rest, you can prematurely go back into focus mode. If you rest for more rest time than you have banked, your rest time goes into the negative numbers. It’s flexible.

User logs in

User clicks focus button
New rest time is added to existing rest time and saved
Starts focus timer
Button turns into Rest button

User clicks Rest button
Focus time is calculated
Focus time is saved or recorded in YAML file
Rest time is calculated
Rest countdown begins

User views history
Shows focus time, rest time, and total study hours for the day.

t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
# => 2810266.714992
t / (24 * 60 * 60.0) # time / days
# => 32.52623512722222
starting = Process.clock_gettime(Process::CLOCK_MONOTONIC)
# time consuming operation
ending = Process.clock_gettime(Process::CLOCK_MONOTONIC)
elapsed = ending - starting
elapsed # => 9.183449000120163 seconds
