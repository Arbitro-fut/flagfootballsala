const config = window.APP_CONFIG || {};
const client = window.supabase.createClient(config.SUPABASE_URL, config.SUPABASE_ANON_KEY);

const els = {
  status: document.getElementById('connectionStatus'),
  email: document.getElementById('emailInput'),
  date: document.getElementById('dateInput'),
  availableFrom: document.getElementById('availableFrom'),
  availableTo: document.getElementById('availableTo'),
  blockList: document.getElementById('blockList'),
  blockCounter: document.getElementById('blockCounter'),
  notes: document.getElementById('notesInput'),
  submit: document.getElementById('submitButton'),
  message: document.getElementById('submitMessage')
};

function setMessage(text, kind = '') {
  els.message.textContent = text || '';
  els.message.className = `message ${kind}`.trim();
}

function selectedParticipates() {
  const selected = document.querySelector('input[name="participates"]:checked');
  return selected ? selected.value === 'true' : true;
}

function todayMx() {
  const now = new Date();
  const yyyy = now.getFullYear();
  const mm = String(now.getMonth() + 1).padStart(2, '0');
  const dd = String(now.getDate()).padStart(2, '0');
  return `${yyyy}-${mm}-${dd}`;
}

function renderBlocks() {
  els.blockList.innerHTML = '';
  for (let i = 0; i < 3; i++) {
    const card = document.createElement('div');
    card.className = 'block-card';
    card.innerHTML = `
      <div class="field-row"><label>Inicio ${i + 1}</label><input class="block-start" type="time" /></div>
      <div class="field-row"><label>Fin ${i + 1}</label><input class="block-end" type="time" /></div>
      <div class="field-row"><label>Motivo</label><input class="block-reason" type="text" maxlength="120" placeholder="Opcional" /></div>`;
    els.blockList.appendChild(card);
  }
  els.blockList.addEventListener('input', updateCounter);
  updateCounter();
}

function collectBlocks(validate = true) {
  const blocks = [];
  for (const card of document.querySelectorAll('.block-card')) {
    const start = card.querySelector('.block-start').value;
    const end = card.querySelector('.block-end').value;
    const reason = card.querySelector('.block-reason').value.trim();
    if (!start && !end && !reason) continue;
    if (validate && (!start || !end)) throw new Error('Cada bloqueo debe tener inicio y fin.');
    if (validate && end <= start) throw new Error('Cada bloqueo debe terminar después de iniciar.');
    if (start && end) blocks.push({ start_time: start, end_time: end, reason });
  }
  return blocks;
}

function updateCounter() {
  els.blockCounter.textContent = `${collectBlocks(false).length} / 3`;
}

async function submitAvailability() {
  const email = els.email.value.trim().toLowerCase();
  const date = els.date.value;
  const participates = selectedParticipates();

  if (!email || !date) {
    setMessage('Captura correo y fecha de jornada.', 'error');
    return;
  }

  if (els.availableTo.value <= els.availableFrom.value) {
    setMessage('El horario disponible debe terminar después de iniciar.', 'error');
    return;
  }

  let blocks = [];
  try {
    blocks = participates ? collectBlocks(true) : [];
  } catch (err) {
    setMessage(err.message, 'error');
    return;
  }

  els.submit.disabled = true;
  setMessage('Enviando disponibilidad...');

  try {
    const { data, error } = await client.rpc('submit_referee_availability_public', {
      p_email: email,
      p_availability_date: date,
      p_participates: participates,
      p_available_from: els.availableFrom.value,
      p_available_to: els.availableTo.value,
      p_unavailable_blocks: blocks,
      p_notes: els.notes.value.trim() || null
    });

    if (error) throw error;
    if (!data?.ok) {
      setMessage(data?.message || 'No fue posible registrar la disponibilidad.', 'error');
      return;
    }

    setMessage(data.message || 'Disponibilidad registrada correctamente.', 'ok');
  } catch (err) {
    console.error(err);
    setMessage(err.message || 'Error al enviar disponibilidad.', 'error');
  } finally {
    els.submit.disabled = false;
  }
}

function boot() {
  if (!config.SUPABASE_URL || !config.SUPABASE_ANON_KEY) {
    els.status.textContent = 'Config incompleta';
    setMessage('Falta configurar Supabase en config.js.', 'error');
    return;
  }
  els.date.value = todayMx();
  renderBlocks();
  els.submit.addEventListener('click', submitAvailability);
  els.status.textContent = 'Listo';
  els.status.className = 'status-pill ok';
}

boot();
