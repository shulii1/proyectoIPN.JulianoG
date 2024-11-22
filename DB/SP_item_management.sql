USE [projectIPN]
GO

-- Si ya existen los SP los elimina
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'SP_item_image_add')
    DROP PROCEDURE SP_item_image_add
GO

IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'SP_item_add')
    DROP PROCEDURE SP_item_add
GO

IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'SP_item_price_list')
    DROP PROCEDURE SP_item_price_list
GO

IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'SP_item_complete_add')
    DROP PROCEDURE SP_item_complete_add
GO


-- SP para agregar imágenes
CREATE PROCEDURE SP_item_image_add
    @url VARCHAR(300),
    @colorId INT,
    @itemId INT 
AS
BEGIN 
    IF @url IS NULL OR TRIM(@url) = ''
    BEGIN
        RAISERROR('La URL de la imagen no puede estar vacía.', 16, 1)
        RETURN
    END

    IF @url NOT LIKE '%.jpg' AND @url NOT LIKE '%.jpeg' AND @url NOT LIKE '%.png' AND @url NOT LIKE '%.gif'
    BEGIN
        RAISERROR('La URL debe terminar en una extensión de imagen válida (.jpg, .jpeg, .png, .gif).', 16, 1)
        RETURN
    END

    IF EXISTS (SELECT 1 FROM TB_img WHERE url_img = @url)
    BEGIN
        RAISERROR('Ya existe esta imagen.', 16, 1)
        RETURN
    END
    IF NOT EXISTS (SELECT 1 FROM TB_color WHERE id_color = @colorId)
    BEGIN
        RAISERROR('Este color no existe en la tabla TB_color.', 16, 1)
        RETURN
    END

    IF NOT EXISTS (SELECT 1 FROM TB_item WHERE id_item = @itemId)
    BEGIN
        RAISERROR('Este producto/artículo no existe en la tabla TB_item.', 16, 1)
        RETURN
    END

    -- valido si ya existe una imagen para este item y color
    IF EXISTS (SELECT 1 FROM TB_img, TB_item WHERE id_color = @colorId AND id_item = @itemId)
    BEGIN
        RAISERROR('Ya existe una imagen para este producto/artículo con este color.', 16, 1)
        RETURN
    END

    INSERT INTO TB_img (url_img, id_color)
    VALUES (@url, @colorId);

    SELECT SCOPE_IDENTITY() AS idColorInsert, 'Imagen insertada correctamente' AS Mensaje;
END;
GO


-- SP para agregar items
CREATE PROCEDURE SP_item_add
    @name VARCHAR(100),
    @sku VARCHAR(20),
    @desc VARCHAR(400),
    @idItemInsert INT OUTPUT
AS
BEGIN
    IF @name IS NULL OR TRIM(@name) = ''
    BEGIN
        RAISERROR('El nombre del producto/artículo no puede estar vacío.', 16, 1)
        RETURN
    END

    IF @sku IS NULL OR TRIM(@sku) = ''
    BEGIN
        RAISERROR('El SKU no puede estar vacío.', 16, 1)
        RETURN
    END

    IF LEN(@sku) < 3
    BEGIN
        RAISERROR('El SKU debe tener al menos 3 caracteres.', 16, 1)
        RETURN
    END

    IF EXISTS (SELECT 1 FROM TB_item WHERE sku = @sku)
    BEGIN
        RAISERROR('Ya existe un producto/artículo con ese SKU.', 16, 1)
        RETURN
    END

    IF LEN(@name) > 100
    BEGIN
        RAISERROR('El nombre no puede exceder los 100 caracteres.', 16, 1)
        RETURN
    END

    IF @desc IS NOT NULL AND LEN(@desc) > 400
    BEGIN
        RAISERROR('La descripción no puede exceder los 400 caracteres.', 16, 1)
        RETURN
    END

    INSERT INTO TB_item (name, sku, description)
    VALUES (@name, @sku, @desc);

    SET @idItemInsert = SCOPE_IDENTITY();
END;
GO


-- SP para lista de precios
CREATE PROCEDURE SP_item_price_list
    @itemId INT,
    @price_list_id INT,
    @price INT 
AS
BEGIN
    IF @price <= 0
    BEGIN
        RAISERROR('El precio debe ser mayor a cero.', 16, 1)
        RETURN
    END

    IF NOT EXISTS (SELECT 1 FROM TB_item WHERE id_item = @itemId)
    BEGIN
        RAISERROR('Este producto/artículo no existe en la tabla TB_item.', 16, 1)
        RETURN
    END

    IF NOT EXISTS (SELECT 1 FROM TB_price_list WHERE id_price_list = @price_list_id)
    BEGIN
        RAISERROR('Esta lista de precio no existe en TB_price_list.', 16, 1)
        RETURN
    END

    IF EXISTS (SELECT 1 FROM TB_item_price_list WHERE id_item = @itemId AND id_price_list = @price_list_id)
    BEGIN
        RAISERROR('Ya existe un precio para este producto/artículo en esta lista de precios.', 16, 1)
        RETURN
    END

    INSERT INTO TB_item_price_list(id_item, id_price_list, price)
    VALUES (@itemId, @price_list_id, @price);

    SELECT SCOPE_IDENTITY() AS id_item_price_list, 'Registro de TB_item_price_list insertado correctamente' AS Mensaje;
END;
GO


-- SP padre
CREATE PROCEDURE SP_item_complete_add
    @url VARCHAR(300),
    @colorId INT,
    @name VARCHAR(100),
    @sku VARCHAR(20),
    @desc VARCHAR(400),
    @price_list_id INT,
    @price INT
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION

        DECLARE @itemId INT;
        
        EXEC SP_item_add @name, @sku, @desc, @itemId OUTPUT;

        EXEC SP_item_image_add @url, @colorId, @itemId;

        EXEC SP_item_price_list @itemId, @price_list_id, @price;

        COMMIT TRANSACTION
        
        SELECT @itemId AS idItemInsertado, 'Producto/Artículo insertado correctamente' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION

        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE()
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY()
        DECLARE @ErrorState INT = ERROR_STATE()

        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
    END CATCH
END;
GO
