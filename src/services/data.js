import { supabase } from '../lib/supabase'

const check = ({ data, error }) => { if (error) throw error; return data }
export const getExercises = async () => check(await supabase.from('exercises').select('*').order('name'))
export const saveExercise = async (exercise) => check(await (exercise.id
  ? supabase.from('exercises').update({ name: exercise.name.trim() }).eq('id', exercise.id).select().single()
  : supabase.from('exercises').insert({ name: exercise.name.trim() }).select().single()))
export const deleteExercise = async (id) => check(await supabase.from('exercises').delete().eq('id', id))
export const getWorkouts = async (status = 'completed') => check(await supabase.from('workouts').select('*, workout_exercises(id, exercise_name, workout_sets(id, weight, reps))').eq('status', status).order(status === 'completed' ? 'completed_at' : 'started_at', { ascending: false }))
export const getWorkout = async (id) => check(await supabase.from('workouts').select('*, workout_exercises(id, exercise_id, exercise_name, position, workout_sets(id, weight, reps, position))').eq('id', id).single())
export const deleteWorkout = async (id) => check(await supabase.from('workouts').delete().eq('id', id))
export const getActiveWorkout = async () => {
  const rows = check(await supabase.from('workouts').select('id').eq('status', 'active').order('started_at').limit(1))
  return rows[0] ?? null
}
export const createWorkout = async () => check(await supabase.from('workouts').insert({ status: 'active' }).select('id').single())
export const addWorkoutExercise = async (workoutId, exercise, position) => check(await supabase.from('workout_exercises').insert({ workout_id: workoutId, exercise_id: exercise.id, exercise_name: exercise.name, position }).select().single())
export const addSet = async (exerciseId, position) => check(await supabase.from('workout_sets').insert({ workout_exercise_id: exerciseId, weight: null, reps: null, position }).select().single())
export const updateSet = async (id, patch) => check(await supabase.from('workout_sets').update(patch).eq('id', id).select().single())
export const removeSet = async (id) => check(await supabase.from('workout_sets').delete().eq('id', id))
export const removeWorkoutExercise = async (id) => check(await supabase.from('workout_exercises').delete().eq('id', id))
export const finishWorkout = async (id) => check(await supabase.from('workouts').update({ status: 'completed', completed_at: new Date().toISOString() }).eq('id', id).eq('status', 'active').select().single())
export const getPreviousExercise = async (exerciseId, workoutId) => {
  const workout = check(await supabase.from('workouts')
    .select('id, completed_at, started_at, workout_exercises!inner(exercise_id, workout_sets(weight, reps, position))')
    .eq('status', 'completed')
    .eq('workout_exercises.exercise_id', exerciseId)
    .neq('id', workoutId)
    .order('completed_at', { ascending: false })
    .order('started_at', { ascending: false })
    .order('id', { ascending: false })
    .limit(1)
    .maybeSingle())

  if (!workout) return null

  const exercise = workout.workout_exercises?.[0]
  if (!exercise) return null

  return {
    workout_sets: exercise.workout_sets || [],
    workouts: { completed_at: workout.completed_at, started_at: workout.started_at },
  }
}
