const taiwanDateTimeFormatter = new Intl.DateTimeFormat('en-CA', {
  timeZone: 'Asia/Taipei',
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
  hour: '2-digit',
  minute: '2-digit',
  hour12: false,
})

const taiwanDateFormatter = new Intl.DateTimeFormat('zh-TW', {
  timeZone: 'Asia/Taipei',
  year: 'numeric',
  month: 'numeric',
  day: 'numeric',
  weekday: 'short',
})

const taiwanTimeFormatter = new Intl.DateTimeFormat('zh-TW', {
  timeZone: 'Asia/Taipei',
  hour: '2-digit',
  minute: '2-digit',
  hour12: false,
})

export function formatTaiwanDateTime(value: string) {
  const parts = taiwanDateTimeFormatter.formatToParts(new Date(value))
    .reduce<Record<string, string>>((result, part) => {
      if (part.type !== 'literal') result[part.type] = part.value
      return result
    }, {})
  return `${parts.year}/${parts.month}/${parts.day} ${parts.hour}:${parts.minute}`
}

export function formatTaiwanDate(value: string) {
  return taiwanDateFormatter.format(new Date(value))
}

export function formatTaiwanTime(value: string) {
  return taiwanTimeFormatter.format(new Date(value))
}

export function taiwanInputToIso(value: string) {
  return new Date(`${value}:00+08:00`).toISOString()
}

export function taiwanDateAndTimeToIso(date: string, time: string) {
  return new Date(`${date}T${time}:00+08:00`).toISOString()
}

export function isoToTaiwanInput(value: string) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Taipei',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  }).formatToParts(new Date(value)).reduce<Record<string, string>>((result, part) => {
    if (part.type !== 'literal') result[part.type] = part.value
    return result
  }, {})
  return `${parts.year}-${parts.month}-${parts.day}T${parts.hour}:${parts.minute}`
}
