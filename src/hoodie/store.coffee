# Store
# ============

# This class defines the API that other Stores have to implement to assure a
# coherent API.
# 
# It also implements some validations and functionality that is the same across
# store impnementations

class Hoodie.Store

  # ## Constructor

  constructor : (@hoodie) ->

  # ## Save

  # saves the passed object into the store and replaces an eventually existing 
  # document with same type & id.
  #
  # When id is undefined, it gets generated and a new object gets saved
  #
  # example usage:
  #
  #     store.save('car', undefined, {color: 'red'})
  #     store.save('car', 'abc4567', {color: 'red'})
  save : (type, id, object, options = {}) ->
    defer = @hoodie.defer()
  
    unless typeof object is 'object'
      defer.reject Hoodie.Errors.INVALID_ARGUMENTS "object is #{typeof object}"
      return defer.promise()
    
    # validations
    if id and not @_isValidId id
      return defer.reject( Hoodie.Errors.INVALID_KEY id: id ).promise()
      
    unless @_isValidType type
      return defer.reject( Hoodie.Errors.INVALID_KEY type: type ).promise()

    return defer
  
  
  # ## Create

  # `.create` is an alias for `.save`, with the difference that there is no id argument.
  # Internally it simply calls `.save(type, undefined, object).
  create : (type, object, options = {}) ->
    @save type, undefined, object
  
  
  # ## Update

  # In contrast to `.save`, the `.update` method does not replace the stored object,
  # but only changes the passed attributes of an exsting object, if it exists
  #
  # both a hash of key/values or a function that applies the update to the passed
  # object can be passed.
  #
  # example usage
  #
  # hoodie.my.store.update('car', 'abc4567', {sold: true})
  # hoodie.my.store.update('car', 'abc4567', function(obj) { obj.sold = true })
  update : (type, id, objectUpdate, options = {}) ->
    defer = @hoodie.defer()
    
    _loadPromise = @load(type, id).pipe (currentObj) => 
      
      # normalize input
      objectUpdate = objectUpdate( $.extend {}, currentObj ) if typeof objectUpdate is 'function'
      
      return defer.resolve currentObj unless objectUpdate
      
      # check if something changed
      changedProperties = for key, value of objectUpdate when currentObj[key] isnt value
        # workaround for undefined values, as $.extend ignores these
        currentObj[key] = value
        key
        
      return defer.resolve currentObj unless changedProperties.length
      
      # apply update 
      @save(type, id, currentObj, options).then defer.resolve, defer.reject
      
    # if not found, create it
    _loadPromise.fail => 
      @save(type, id, objectUpdate, options).then defer.resolve, defer.reject
    
    defer.promise()
  
  
  # ## updateAll

  # update all objects in the store, can be optionally filtered by a function
  # As an alternative, an array of objects can be passed
  #
  # example usage
  #
  # hoodie.my.store.updateAll()
  updateAll : (filterOrObjects, objectUpdate, options = {}) ->
    
    # normalize the input: make sure we have all objects
    switch true
      when typeof filterOrObjects is 'string'
        promise = @loadAll filterOrObjects
      when @hoodie.isPromise(filterOrObjects)
        promise = filterOrObjects  
      when $.isArray filterOrObjects
        promise = @hoodie.defer().resolve( filterOrObjects ).resolve()
      else # e.g. null, update all
        promise = @loadAll()
    
    promise.pipe (objects) =>
      
      # now we update all objects one by one and return a promise
      # that will be resolved once all updates have been finished
      defer = @hoodie.defer()
      _updatePromises = for object in objects
        @update(object.type, object.id, objectUpdate, options) 
      $.when.apply(null, _updatePromises).then defer.resolve
      
      return defer.promise()
  
  
  # ## load

  # loads one object from Store, specified by `type` and `id`
  #
  # example usage:
  #
  #     store.load('car', 'abc4567')
  load : (type, id) ->
    defer = @hoodie.defer()
  
    unless typeof type is 'string' and typeof id is 'string'
      return defer.reject( Hoodie.Errors.INVALID_ARGUMENTS "type & id are required" ).promise()
  
    return defer
  
  
  # ## loadAll

  # returns all objects from store. 
  # Can be optionally filtered by a type or a function
  loadAll : () ->
    @hoodie.defer()
  
  
  # ## Delete

  # Deletes one object specified by `type` and `id`. 
  # 
  # when object has been synced before, mark it as deleted. 
  # Otherwise remove it from Store.
  delete : (type, id, options = {}) ->
    defer = @hoodie.defer()
  
    unless typeof type is 'string' and typeof id is 'string'
      return defer.reject( Hoodie.Errors.INVALID_ARGUMENTS "type & id are required" ).promise()

    return defer
  
  # alias
  destroy: -> @delete arguments...


  # ## deleteAll

  # Deletes all objects. Can be filtered by a type
  deleteAll : (type, options = {}) -> 
    @hoodie.defer()

  # alias
  destroyAll: @::deleteAll  

  # ## UUID

  # helper to generate uuids.
  uuid : (len = 7) ->
    chars = '0123456789abcdefghijklmnopqrstuvwxyz'.split('')
    radix = chars.length
    (
      chars[ 0 | Math.random()*radix ] for i in [0...len]
    ).join('')
  
  # ## Private

  #
  _now : -> new Date

  # only lowercase letters, numbers and dashes are allowed for ids
  _isValidId : (key) ->
    /^[a-z0-9\-]+$/.test key
    
  # just like ids, but must start with a letter or a $ (internal types)
  _isValidType : (key) ->
    /^[a-z$][a-z0-9]+$/.test key