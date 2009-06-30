require 'thread'
require 'timeout'

class ObjectPool
  ObjectPool::Version = '0.0.1' unless defined?(ObjectPool::Version)
  def ObjectPool.version() ObjectPool::Version end

  class Error < ::StandardError; end

  attr :size

  def initialize(*args, &block)
    @options = args.last.is_a?(Hash) ? args.pop : {}
    @objects = args
    @size = @options[:size] || @options['size']
    @size ||= @objects.size unless @objects.empty?
    @size ||= 4.2
    @size = Integer(@size)
    @used = {}
    @mutex = Mutex.new
    @cond = ConditionVariable.new
    @locked = false
    @block = block
  end

  def new_object
    @block.call if @block
  end

  def create_object?
    @objects.size < @size and @block
  end

  def put(object)
    lock{ @objects.push(object) }
  end

  def get(*args, &block)
    options = args.last.is_a?(Hash) ? args.pop : {}

    blocking = true
    blocking = options[:blocking] if options.has_key?(:blocking)
    blocking = options['blocking'] if options.has_key?('blocking')

    object = checkout(blocking)

    if block
      begin
        return block.call(object)
      ensure
        checkin(object)
      end
    else
      return object
    end
  end

  def checkout(blocking=true)
    lock {
      loop do
        if create_object?
          @objects << (object = new_object())
          @used[object] = Thread.current
          return object
        end

        free = @objects.select{|object| not @used[object]}
        unless free.empty?
          object = free[ rand(free.size) ]
          @used[object] = Thread.current
          return object
        end

        raise Error, "no free object!" unless blocking
        wait_unlocked
      end
    }
    raise Error, "wtf!?"
  end

  def checkin(object)
    lock {
      @used.delete(object)
      @cond.signal
    }
  end

  def wait_unlocked
    @cond.wait(@mutex)
  end

  def lock(&block)
    return block.call if thread[thread_key(:lock)]
    synchronize do
      begin
        thread[thread_key(:lock)] = true
        block.call
      ensure
        thread[thread_key(:lock)] = false
      end
    end
  end

  def locked?
    thread[thread_key(:lock)]
  end

  def thread
    Thread.current
  end

  def thread_key(*suffix)
    [ "ObjectPool[#{ object_id }]", *suffix ].join('.')
  end

  def synchronize(&block)
    @mutex.synchronize(&block)
  end

  def each(&block)
    lock{ @objects.each(&block) }
  end

  def objects(&block)
    return @objects if locked?
    raise ArgumentError, "no block" unless block
    lock{ block.call(@objects) }
  end
end

Objectpool = ObjectPool

def ObjectPool(*args, &block)
  ObjectPool.new(*args, &block)
end

def Objectpool(*args, &block)
  Objectpool.new(*args, &block)
end





if $0 == __FILE__
 
# test bitch fighting over the objects - this should run forever
#
  require 'yaml'
  require 'time'

  n = 2**10

  loop do
# configure a randomly sized pool
#
    #size = [ 1, rand(42) ].max
    #arrays = Array.new(size){ Array.new }
    #pool = ObjectPool.new *arrays
    pool = ObjectPool.new{ Array.new }

    q = Queue.new

# setup the bitch fight
#
    busy =
      Thread.new do
        Thread.current.abort_on_exception=true
        loop{ pool.get{} }
      end

    n.times do |i|
      Thread.new do
        Thread.current.abort_on_exception=true
        sleep rand

        Thread.new do
          Thread.current.abort_on_exception=true
          sleep rand
          pool.get{|array| array.push(i)}
          q.push Thread.current.object_id
        end
      end
    end

# wait for all threads
#
    n.times{ q.pop }

# blow up if any thread still appears to be running
#
    sleep(rand)

    loop do
      begin
        q.pop(non_block=true)
        fail
      rescue ThreadError
        break
      end
    end

# check our results - puke if they look to be crap
#
    pool.lock do
      values = pool.objects.flatten

      if values.size==values.uniq.size
        y 'pass' => Time.now.iso8601(2)
      else
        y(
          'size' => values.size,
          'uniq' => values.uniq.size,
          'fail' => Time.now.iso8601(2)
        )
        abort
      end
    end

    busy.kill
  end
end
