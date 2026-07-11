// ════════════════════════════════════════════════════════
//  CHEST REVEAL
// ════════════════════════════════════════════════════════
function showChest(chest) {
  if (chest.got_freeze) {
    document.getElementById('chest-icon').textContent = '❄️';
    document.getElementById('chest-msg').textContent  = T.chestGotFreeze;
    document.getElementById('chest-sub').textContent  = chest.streak != null ? T.chestStreak(chest.streak) : T.chestSub;
  } else {
    document.getElementById('chest-icon').textContent = '🎁';
    document.getElementById('chest-msg').textContent  = T.chestNoReward;
    document.getElementById('chest-sub').textContent  = chest.streak != null ? T.chestStreak(chest.streak) : '';
  }
  document.getElementById('chest-close').textContent = T.chestOk;
  openOv('modal-chest');
}
document.getElementById('chest-close').addEventListener('click', () => closeOv('modal-chest'));
document.getElementById('modal-chest').addEventListener('click', e => { if (e.target === e.currentTarget) closeOv('modal-chest'); });

// ════════════════════════════════════════════════════════
//  EDIT PROFILE MODAL
// ════════════════════════════════════════════════════════
function openEditProfile() {
  if (!userProfile) return;
  epSelEmoji = userProfile.avatarEmoji;
  epSelColor = userProfile.avatarColor;
  epSelImg = userProfile.avatarImg || null;

  const prev = document.getElementById('ep-preview');
  prev.dataset.emoji = epSelEmoji;
  prev.dataset.color = epSelColor;
  const epUploadBtn = document.getElementById('ep-upload-btn');
  document.getElementById('ep-upload-msg').style.display = 'none';
  if (epSelImg && epSelImg.startsWith('data:image/')) {
    prev.innerHTML = `<img src="${epSelImg}" style="width:100%;height:100%;object-fit:cover;border-radius:50%">`;
    prev.style.background = 'transparent';
    epUploadBtn.textContent = T.removePhoto;
    epUploadBtn.dataset.hasImg = '1';
  } else {
    prev.textContent = epSelEmoji;
    prev.style.background = epSelColor;
    epUploadBtn.textContent = T.uploadPhoto;
    epUploadBtn.dataset.hasImg = '0';
  }
  document.getElementById('ep-name').value = userProfile.name;
  document.getElementById('ep-error').textContent = '';

  const eg = document.getElementById('ep-emoji-grid');
  eg.innerHTML = AVATAR_EMOJIS.map(em =>
    `<div class="emoji-cell${em===epSelEmoji?' sel':''}" data-emoji="${em}">${em}</div>`
  ).join('');
  eg.querySelectorAll('.emoji-cell').forEach(c => {
    c.addEventListener('click', () => {
      eg.querySelectorAll('.emoji-cell').forEach(x=>x.classList.remove('sel'));
      c.classList.add('sel');
      epSelEmoji = c.dataset.emoji;
      prev.dataset.emoji = epSelEmoji;
      if (!epSelImg) prev.textContent = epSelEmoji;
    });
  });

  const cg = document.getElementById('ep-color-grid');
  cg.innerHTML = AVATAR_COLORS.map(col =>
    `<div class="color-dot${col===epSelColor?' sel':''}" data-color="${col}" style="background:${col}"></div>`
  ).join('');
  cg.querySelectorAll('.color-dot').forEach(c => {
    c.addEventListener('click', () => {
      cg.querySelectorAll('.color-dot').forEach(x=>x.classList.remove('sel'));
      c.classList.add('sel');
      epSelColor = c.dataset.color;
      prev.dataset.color = epSelColor;
      if (!epSelImg) prev.style.background = epSelColor;
    });
  });

  openPage('modal-edit-profile');
  setTimeout(() => document.getElementById('ep-name').focus(), 350);
}

document.getElementById('ep-cancel').addEventListener('click', () => closePage('modal-edit-profile'));

document.getElementById('ep-submit').addEventListener('click', async () => {
  const newName = document.getElementById('ep-name').value.trim();
  const errEl   = document.getElementById('ep-error');
  if (!newName) { errEl.textContent = T.psuErrName; return; }
  errEl.textContent = '';
  document.getElementById('ep-submit').disabled = true;
  try {
    await api.updateUser(group.id, userProfile.userId, {
      name: newName, avatarEmoji: epSelEmoji, avatarColor: epSelColor,
      avatarImg: epSelImg,
      recoveryCode: userProfile.recoveryCode
    });
    userProfile.name = newName; userProfile.avatarEmoji = epSelEmoji; userProfile.avatarColor = epSelColor; userProfile.avatarImg = epSelImg;
    saveUser(group.id, userProfile);
    closePage('modal-edit-profile');
    await refresh();
    updateMyProfileBtn();
    showToast(T.toastProfileSaved);
  } catch(e) {
    errEl.textContent = e.status===409 ? T.errNameTaken : T.errServer;
  } finally { document.getElementById('ep-submit').disabled = false; }
});

