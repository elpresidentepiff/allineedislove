const screens = [...document.querySelectorAll('.screen')];
const label = document.getElementById('screenLabel');
let selectedMode = 'voice';
let sessionSeconds = 0;
let timerHandle = null;

const names = {
  welcome: 'Welcome', pair: 'Create Pair', invite: 'Invite Acceptance', waiting: 'Waiting',
  connected: 'Connected', home: 'Right Now', together: 'Together', incoming: 'Incoming Request',
  live: 'Together Now', ended: 'Session Ended', story: 'Our Story', us: 'Us', controls: 'Controls',
  private: 'Private Time', disconnect: 'Disconnect', disconnected: 'Disconnected'
};

function go(name){
  screens.forEach(screen => screen.classList.toggle('active', screen.dataset.screen === name));
  if(label) label.textContent = names[name] || name;
  if(name !== 'live') stopTimer();
  if(name === 'live') startTimer();
  const active = document.querySelector(`.screen[data-screen="${name}"]`);
  if(active) active.scrollTop = 0;
}

function modeDescription(mode){
  if(mode === 'video') return 'Video · nothing starts until you accept.';
  if(mode === 'screen') return 'Shared presentation · you will see exactly when sharing begins.';
  return 'Voice · nothing starts until you accept.';
}

function startTimer(){
  sessionSeconds = 0;
  updateTimer();
  clearInterval(timerHandle);
  timerHandle = setInterval(() => {
    sessionSeconds += 1;
    updateTimer();
  }, 1000);
}

function stopTimer(){
  if(timerHandle){
    clearInterval(timerHandle);
    timerHandle = null;
  }
}

function updateTimer(){
  const timer = document.getElementById('timer');
  if(!timer) return;
  const minutes = String(Math.floor(sessionSeconds / 60)).padStart(2,'0');
  const seconds = String(sessionSeconds % 60).padStart(2,'0');
  timer.textContent = `${minutes}:${seconds}`;
}

document.addEventListener('click', event => {
  const goButton = event.target.closest('[data-go]');
  if(goButton){
    go(goButton.dataset.go);
    return;
  }

  const mode = event.target.closest('.moment-option');
  if(mode){
    selectedMode = mode.dataset.mode;
    document.querySelectorAll('.moment-option').forEach(option => {
      const selected = option === mode;
      option.classList.toggle('selected', selected);
      option.querySelector('b').textContent = selected ? '✓' : '';
    });
    return;
  }

  const toggle = event.target.closest('.switch');
  if(toggle){
    const on = toggle.classList.toggle('on');
    toggle.setAttribute('aria-pressed', String(on));
  }
});

document.getElementById('sendMoment')?.addEventListener('click', () => {
  const description = document.getElementById('incomingMode');
  if(description) description.textContent = modeDescription(selectedMode);
  go('incoming');
});

document.getElementById('endCall')?.addEventListener('click', () => {
  const summary = document.getElementById('sessionLength');
  if(summary){
    if(sessionSeconds < 10) summary.textContent = 'A few seconds';
    else if(sessionSeconds < 60) summary.textContent = `${sessionSeconds} seconds`;
    else summary.textContent = `${Math.max(1, Math.round(sessionSeconds / 60))} minutes`;
  }
  stopTimer();
  go('ended');
});

document.getElementById('privateTime')?.addEventListener('click', () => go('private'));

go('welcome');
